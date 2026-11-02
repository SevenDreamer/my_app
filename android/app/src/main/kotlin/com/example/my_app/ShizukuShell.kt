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

        fun isAvailable(): Boolean = try {
            Shizuku.pingBinder()
        } catch (e: Throwable) { false }

        fun hasPermission(): Boolean = try {
            isAvailable() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (e: Throwable) { false }

        fun isReady(): Boolean {
            val current = service ?: return false
            return hasPermission() && try {
                current.asBinder().pingBinder()
            } catch (e: Throwable) { false }
        }

        fun status(): String {
            val bound = isReady()
            val binding = connection != null && service == null
            return "binder=${isAvailable()},permission=${hasPermission()},bound=$bound,binding=$binding" +
                if (failure.isEmpty()) "" else ",error=$failure"
        }

        fun requestPermission(onResult: (granted: Boolean) -> Unit) {
            MAIN.post {
                if (hasPermission()) {
                    ensureBound()
                    onResult(true)
                    return@post
                }
                try {
                    val listener = object : Shizuku.OnRequestPermissionResultListener {
                        override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                            try { Shizuku.removeRequestPermissionResultListener(this) } catch (_: Throwable) {}
                            val granted = grantResult == PackageManager.PERMISSION_GRANTED
                            if (granted) ensureBound()
                            onResult(granted)
                        }
                    }
                    Shizuku.addRequestPermissionResultListener(listener)
                    Shizuku.requestPermission(9527)
                } catch (e: Throwable) {
                    failure = e.message ?: "SHIZUKU_PERMISSION_FAILED"
                    onResult(false)
                }
            }
        }

        fun ensureBound() {
            init(context)
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
            ).daemon(false).processNameSuffix("shell").debuggable(false).version(1)
            val conn = object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                    service = IShellService.Stub.asInterface(binder)
                }
                override fun onServiceDisconnected(name: ComponentName?) {
                    service = null
                }
            }
            connection = conn
            try {
                Shizuku.bindUserService(args, conn)
            } catch (e: Throwable) {
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

        /// 虚拟屏命令执行（原版 execVirtualScreen 通道）。
        fun execVirtualScreen(command: String): String {
            val current = service
                ?: return "SHIZUKU_NOT_READY ${status()}"
            return try {
                current.execVirtualScreen(command)
            } catch (e: Throwable) {
                "SHIZUKU_EXEC_FAILED ${e.message ?: ""}"
            }
        }
    }
}
