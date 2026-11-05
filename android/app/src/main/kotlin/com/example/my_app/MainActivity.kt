package com.example.my_app

import java.lang.ref.WeakReference

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** 应用在屏（resumed）——dsh-go 融合契约（icons/launch/pet 等域引用）。
         *  属性可写范围限本类维护（private set 语义）。 */
        @Volatile
        @JvmStatic
        var inForeground = false
            private set

        /** 当前 Activity 弱引用（需要 Activity 的能力插件取用）。 */
        @Volatile
        @JvmStatic
        var current: WeakReference<MainActivity>? = null
            private set
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        current = WeakReference(this)
    }

    override fun onResume() {
        super.onResume()
        inForeground = true
    }

    override fun onPause() {
        inForeground = false
        super.onPause()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // 启动崩溃兜底最先装（ContentProvider 期崩溃的补报机制）。
        com.example.my_app.StartupCrashRecorder.install(applicationContext)
        super.configureFlutterEngine(flutterEngine)
        // dsh-go 融合层（批次 4）：其 FlutterPlugin 全量注册（runtime 事件流/
        // 桌宠/手机操控/图标/分享等通道在此挂载；缺注册 = MissingPluginException）。
        with(flutterEngine.plugins) {
            add(com.example.my_app.runtime.RuntimePlugin())
            add(com.example.my_app.phone.PhonePlugin())
            add(com.example.my_app.notify.NotifyPlugin())
            add(com.example.my_app.files.FilesPlugin())
            add(com.example.my_app.links.LinksPlugin())
            add(com.example.my_app.update.UpdatePlugin())
            add(com.example.my_app.voice.VoicePlugin())
            add(com.example.my_app.share.SharePlugin())
            add(com.example.my_app.shortcuts.ShortcutsPlugin())
            add(com.example.my_app.diagnostics.DiagnosticsPlugin())
            add(com.example.my_app.media.MediaPlugin())
            add(com.example.my_app.icons.LauncherIconPlugin())
            add(com.example.my_app.theme.DynamicColorPlugin())
            add(com.example.my_app.performance.PerformancePlugin())
            add(com.example.my_app.pet.PetOverlayPlugin())
            add(com.example.my_app.islands.IslandsPlugin())
            add(com.example.my_app.nativemedia.NativeMediaPlugin())
            add(com.example.my_app.nativefiles.NativeFilesPlugin())
            add(com.example.my_app.web.WebFilesPlugin())
            add(com.example.my_app.launch.LaunchPlugin())
            add(com.example.my_app.launch.LaunchClipPlugin())
            add(com.example.my_app.icons.PictureShortcutPlugin())
            add(com.example.my_app.usage.UsagePlugin())
        }
        // Runtime channel: nativeLibraryDir is the only exec-allowed dir on
        // Android 10+ (W^X) — proot ships as jniLibs and runs from there.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_app/runtime")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                    "dataDir" -> result.success(applicationInfo.dataDir)
                    "sourceDir" -> result.success(applicationInfo.sourceDir)
                    "packageName" -> result.success(packageName)
                    "runtimeForegroundStart" -> {
                        // 前台服务保活（原版 HarnessService：常驻通知降回收；
                        // Android 8+ 5 秒 startForeground 硬契约在服务内守）。
                        val intent = android.content.Intent(
                            this, com.example.my_app.RuntimeForegroundService::class.java
                        )
                        androidx.core.content.ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }
                    "runtimeForegroundStop" -> {
                        stopService(android.content.Intent(
                            this, com.example.my_app.RuntimeForegroundService::class.java))
                        result.success(true)
                    }
                    "startupCrashConsume" ->
                        result.success(com.example.my_app.StartupCrashRecorder.consume(applicationContext))
                    "logcatSnapshot" -> {
                        try {
                            val p = Runtime.getRuntime().exec(arrayOf(
                                "logcat", "-d", "-t", "300", "-v", "brief"))
                            val text = p.inputStream.bufferedReader().readText()
                            p.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)
                            // 只留 Shizuku/Shell/崩溃相关段（诊断包瘦身）。
                            val kept = text.lines().filter {
                                it.contains("Shizuku") || it.contains("shizuku") ||
                                    it.contains("ShellService") || it.contains("ShizukuShell") ||
                                    it.contains("AndroidRuntime") || it.contains("FATAL") ||
                                    it.contains("bindUserService") || it.contains("UserService")
                            }.takeLast(80).joinToString("\n")
                            result.success(kept)
                        } catch (e: Throwable) {
                            result.success("LOGCAT_FAILED ${e.message ?: ""}")
                        }
                    }
                    "shizukuInit" -> {
                        com.example.my_app.ShizukuShell.init(applicationContext)
                        result.success(true)
                    }
                    "shizukuStatus" -> result.success(com.example.my_app.ShizukuShell.status())
                    "shizukuReady" -> result.success(com.example.my_app.ShizukuShell.isReady())
                    "shizukuRequestPermission" -> {
                        com.example.my_app.ShizukuShell.requestPermission { granted ->
                            runOnUiThread { result.success(granted) }
                        }
                    }
                    "shizukuExec" -> {
                        val command = call.argument<String>("command") ?: ""
                        result.success(com.example.my_app.ShizukuShell.execVirtualScreen(command))
                    }
                    "deviceDns" -> {
                        // 设备 DNS（prepareResolver 来源）：连接管理器的链路 DNS。
                        val cm = getSystemService(android.content.Context.CONNECTIVITY_SERVICE)
                            as android.net.ConnectivityManager
                        val servers = cm.allNetworks.mapNotNull { net ->
                            cm.getLinkProperties(net)?.dnsServers?.map { it.hostAddress }
                        }.flatten().filterNotNull().distinct()
                        result.success(servers)
                    }
                    else -> result.notImplemented()
                }
            }
        // Lifecycle channel: a Shorebird patch only takes effect after a full
        // process restart, so relaunch into a fresh task and exit ourselves.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_app/lifecycle")
            .setMethodCallHandler { call, result ->
                if (call.method == "restart") {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    }
                    startActivity(intent)
                    Runtime.getRuntime().exit(0)
                } else {
                    result.notImplemented()
                }
            }
    }
}
