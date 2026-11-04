package com.example.my_app

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.Looper
import android.os.Handler
import rikka.shizuku.Shizuku

// Shizuku-backed shell channel (ported contract from DSHA's ShizukuShell +
// ShellService): UserService runs our IShellService as shell uid; commands
// execute through it. Behavior contract preserved: status text surface,
// permission request flow, and execVirtualScreen entry.
class ShizukuShell private constructor() {
    companion object {
        private val MAIN = Handler(Looper.getMainLooper())
        private val LOCK = Any()
        @Volatile private var context: Context? = null
        @Volatile private var service: IShellService? = null
        @Volatile private var connection: ServiceConnection? = null
        @Volatile private var failure = ""
        private var listening = false

        @JvmStatic
        fun init(ctx: Context?) {
            if (ctx != null) context = ctx.applicationContext
            synchronized(LOCK) {
                if (listening || context == null) return
                listening = true
            }
            try {
                Shizuku.addBinderDeadListener {
                    MAIN.post { disconnect("Shizuku 服务已停止") }
                }
                Shizuku.addBinderReceivedListenerSticky {
                    MAIN.post { ensureBound() }
                }
            } catch (e: Throwable) {
                synchronized(LOCK) { listening = false }
                failure = e.message ?: "SHIZUKU_INIT_FAILED"
            }
        }

        @JvmStatic
        fun isAvailable(): Boolean = try {
            Shizuku.pingBinder()
        } catch (e: Throwable) { false }

        @JvmStatic
        fun hasPermission(): Boolean = try {
            isAvailable() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (e: Throwable) { false }

        @JvmStatic
        fun isReady(): Boolean {
            val current = service ?: return false
            return hasPermission() && try {
                current.asBinder().pingBinder()
            } catch (e: Throwable) { false }
        }

        @JvmStatic
        fun status(): String {
            val bound = isReady()
            val binding = connection != null && service == null
            return "binder=${isAvailable()},permission=${hasPermission()},bound=$bound,binding=$binding" +
                if (failure.isEmpty()) "" else ",error=$failure"
        }

        @JvmStatic
        fun requestPermission(onResult: (granted: Boolean) -> Unit) {
            MAIN.post {
                if (hasPermission()) {
                    ensureBound()
                    onResult(true)
                    return@post
                }
                try {
                    val completed = booleanArrayOf(false)
                    val listener = object : Shizuku.OnRequestPermissionResultListener {
                        override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                            if (completed[0]) return
                            completed[0] = true
                            try { Shizuku.removeRequestPermissionResultListener(this) } catch (_: Throwable) {}
                            val granted = grantResult == PackageManager.PERMISSION_GRANTED
                            if (granted) ensureBound()
                            onResult(granted)
                        }
                    }
                    Shizuku.addRequestPermissionResultListener(listener)
                    Shizuku.requestPermission(9527)
                    // 60s 超时（原版契约：授权请求尚未完成按拒绝收场，不留挂起）。
                    MAIN.postDelayed({
                        if (!completed[0]) {
                            completed[0] = true
                            failure = "授权请求尚未完成，请重试"
                            try { Shizuku.removeRequestPermissionResultListener(listener) } catch (_: Throwable) {}
                            onResult(false)
                        }
                    }, 60_000)
                } catch (e: Throwable) {
                    failure = e.message ?: "SHIZUKU_PERMISSION_FAILED"
                    onResult(false)
                }
            }
        }

        /// 原版 ensureBound(Context) 契约：带参可显式供 Context（@JvmOverloads
        /// 兼容无参旧调用）。
        @JvmStatic
        @JvmOverloads
        fun ensureBound(ctx: Context? = null) {
            init(ctx ?: context)
            if (Looper.myLooper() != Looper.getMainLooper()) {
                MAIN.post { ensureBound() }
                return
            }
            val ctx = context ?: return
            if (!hasPermission()) {
                if (connection != null) disconnect("")
                return
            }
            if (isReady()) return
            if (service != null) disconnect("")
            if (connection != null) return
            failure = ""
            val args = Shizuku.UserServiceArgs(
                ComponentName(ctx.packageName, ShellService::class.java.name)
            ).processNameSuffix("shizuku").tag("dsha-device-shell")
                .daemon(false).debuggable(false).version(1)
            val conn = object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                    android.util.Log.i("ShizukuShell", "onServiceConnected: binder=$binder")
                    service = IShellService.Stub.asInterface(binder)
                }
                override fun onServiceDisconnected(name: ComponentName?) {
                    android.util.Log.w("ShizukuShell", "onServiceDisconnected")
                    service = null
                }
            }
            connection = conn
            android.util.Log.i("ShizukuShell", "bindUserService: dispatching args=$args")
            try {
                Shizuku.bindUserService(args, conn)
                android.util.Log.i("ShizukuShell", "bindUserService: dispatched, awaiting callback")
            } catch (e: Throwable) {
                android.util.Log.e("ShizukuShell", "bindUserService: failed", e)
                failure = e.message ?: "SHIZUKU_BIND_FAILED"
                connection = null
            }
        }

        private fun disconnect(reason: String) {
            val conn = connection
            connection = null
            service = null
            if (reason.isNotEmpty()) failure = reason
            val ctx = context ?: return
            if (conn != null) {
                try {
                    Shizuku.unbindUserService(
                        Shizuku.UserServiceArgs(
                            ComponentName(ctx.packageName, ShellService::class.java.name)
                        ), conn, true
                    )
                } catch (_: Throwable) {}
            }
        }

        /// Shizuku 管理器安装检测（原版 isInstalled 契约）。
        @JvmStatic
        fun isInstalled(ctx: Context): Boolean {
            return isAvailable() || com.example.my_app.ShizukuManagerCompat.manager(ctx) != null
        }

        /// 用户可读状态文案（原版 userStatus 契约，文案逐字保留）。
        @JvmStatic
        fun userStatus(ctx: Context): String {
            if (!isAvailable()) {
                return if (isInstalled(ctx)) {
                    com.example.my_app.util.UiText.text(
                        "管理器已安装，服务尚未连接。点击授权重新连接；若仍未连接，请启动管理器服务，并检查隐藏模式是否允许 DSHA。")
                } else {
                    com.example.my_app.util.UiText.text("尚未安装 Shizuku。安装并启动后可在这里授权。")
                }
            }
            if (!hasPermission()) {
                return com.example.my_app.util.UiText.text("服务已连接，尚未授权 DSHA。点击下方授权。")
            }
            if (isReady()) {
                return com.example.my_app.util.UiText.text("已授权 · 设备 Shell 已连接，可直接使用，无需 ADB 配对")
            }
            if (failure.isNotEmpty()) {
                return com.example.my_app.util.UiText.format("已授权，连接失败：%s。点击下方重试。", failure)
            }
            return com.example.my_app.util.UiText.text("已授权，正在连接设备 Shell…")
        }

        /// 通用 Binder exec（原版 ShizukuShell.exec 契约）。
        @JvmStatic
        fun exec(command: String): String {
            val current = service
                ?: return "[SHIZUKU_SERVICE_NOT_READY] ${status()}\n[EXIT=124]"
            return try {
                current.exec(command)
            } catch (e: Throwable) {
                "SHIZUKU_EXEC_FAILED ${e.message ?: ""}"
            }
        }

        /// 虚拟屏命令执行（原版 execVirtualScreen 通道）。
        /// 错误分支补 [EXIT=码] 尾标（原版逐字契约：not-ready=124 / 未确认=125）——
        /// Dart 握手与完整性判定（endsWith("[EXIT=0]")）只认带尾标的输出。
        @JvmStatic
        fun execVirtualScreen(command: String): String {
            val current = service
                ?: return "SHIZUKU_NOT_READY ${status()}\n[EXIT=124]"
            return try {
                current.execVirtualScreen(command)
            } catch (e: Throwable) {
                "SHIZUKU_EXEC_FAILED ${e.message ?: ""}\n[EXIT=125]"
            }
        }

        /// 类型化虚拟屏命令（原版 execVirtualScreenTyped 契约：就绪判定 +
        /// DeviceTransportResult 类型化结果，语义逐字保留）。
        @JvmStatic
        fun execVirtualScreenTyped(command: String): com.example.my_app.device.DeviceTransportResult {
            val current = service
                ?: return com.example.my_app.device.DeviceTransportResult.notSent(
                    "shizuku",
                    "SHIZUKU_SERVICE_NOT_READY",
                    "[SHIZUKU_SERVICE_NOT_READY] ${status()}\n[EXIT=124]",
                )
            return try {
                com.example.my_app.device.DeviceTransportResult.fromLegacy(
                    "shizuku",
                    current.execVirtualScreen(command),
                    com.example.my_app.device.DeviceTransportIdentity.unknown(),
                )
            } catch (error: Throwable) {
                com.example.my_app.device.DeviceTransportResult.unknown(
                    "shizuku",
                    "SHIZUKU_EXECUTION_UNKNOWN",
                    "[EXECUTION_UNKNOWN] VSCREEN_RESULT_UNKNOWN\n[EXIT=125]",
                    false,
                    com.example.my_app.device.DeviceTransportIdentity.unknown(),
                )
            }
        }
    }
}
