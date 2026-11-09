// [归属] Linux 底座引擎（语义归 docs/LINUX_BASE_PLAN.md；本文件名保持 DSH 语义不改名）。
package com.example.my_app.runtime

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import io.flutter.plugin.common.PluginRegistry

/** Flutter bridge for the local runtime: MethodChannel `dsh/runtime`, EventChannel `dsh/runtime/events`. */
class RuntimePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var controller: RuntimeController
    private lateinit var appContext: android.content.Context
    private var sink: RuntimeController.EventSink? = null
    private var activity: ActivityPluginBinding? = null
    private var pendingStorageResult: MethodChannel.Result? = null
    private var managedSkillOwner: ManagedSkillOwner? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        controller = RuntimeController.get(binding.applicationContext)
        managedSkillOwner = controller.attachManagedSkillOwner()
        methods = MethodChannel(binding.binaryMessenger, "dsh/runtime").also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "dsh/runtime/events").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        managedSkillOwner?.let { owner ->
            controller.detachManagedSkillOwner(owner)
        }
        managedSkillOwner = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink?.let { controller.removeSink(it) }
        sink = null
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activity?.removeRequestPermissionsResultListener(this)
        activity = null
    }

    /** 桥接 IO 执行器（2026-11-09）：触碰 manifest/文件系统/网络的 handler
     *  一律下工作线程（MethodChannel 主线程跑网络 = NetworkOnMainThread /
     *  ANR——镜像上 R2 后实证）。MethodChannel.Result 跨线程回合法。 */
    private val bridgeIo = java.util.concurrent.Executors.newSingleThreadExecutor {
        Thread(it, "dsh-bridge")
    }

    /** 需要下工作线程的方法（触碰 manifest lazy load / 网络 / 大文件）。 */
    private val heavyMethods = setOf(
        "getStatus", "install", "baseStats",
        "snapshotList", "snapshotCreate", "snapshotDelete", "snapshotRestore",
        "lastKnownGood", "restoreLastKnownGood", "safePreflight", "moveAside",
        "failureLog", "storageStatus",
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method in heavyMethods) {
            bridgeIo.execute {
                try {
                    dispatch(call, result)
                } catch (t: Throwable) {
                    result.error("bridge_io", t.message ?: t.javaClass.simpleName, null)
                }
            }
        } else {
            dispatch(call, result)
        }
    }

    private fun dispatch(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(controller.status())
            "publishDiagnostics" -> {
                val markdown = call.argument<String>("markdown")
                result.success(if (markdown == null || markdown.length > 256 * 1024) null else controller.publishDiagnostics(markdown))
            }
            "installManagedSkill" -> {
                val owner = managedSkillOwner
                if (owner == null) result.success(mapOf("result" to null, "current" to false, "reason" to "stale"))
                else controller.installManagedSkill(owner, call.arguments, result::success)
            }
            "cancelManagedSkill" -> {
                val requestId = (call.arguments as? Map<*, *>)?.get("requestId") as? String
                if (requestId != null && requestId.length in 1..200) {
                    managedSkillOwner?.let { controller.cancelManagedSkill(it, requestId) }
                }
                result.success(null)
            }
            "install" -> {
                // A second call must not end the running unpack's foreground service.
                if (controller.phase == RuntimeController.Phase.INSTALLING) return result.error("install_busy", null, null)
                val intent = Intent(appContext, DshService::class.java).setAction(DshService.ACTION_INSTALL)
                    .putExtra("upgrade", controller.status()["installedVersion"] != null)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) appContext.startForegroundService(intent)
                else appContext.startService(intent)
                controller.install(dropKept = call.argument<Boolean>("dropKept") == true) { error ->
                    appContext.startService(
                        Intent(appContext, DshService::class.java).setAction(DshService.ACTION_INSTALL_DONE)
                            .putExtra(DshService.EXTRA_INSTALL_OK, error == null),
                    )
                    if (error == null) result.success(null) else result.error("install_failed", error.message, null)
                }
            }
            "start" -> {
                val env = (call.argument<Map<String, Any?>>("env") ?: emptyMap())
                    .mapNotNull { (k, v) -> v?.toString()?.let { k to it } }.toMap()
                controller.start(
                    env,
                    phoneStorage = call.argument<Boolean>("phoneStorage") == true,
                    mode = call.argument<String>("mode"),
                    visualReplies = call.argument<Boolean>("visualReplies") != false,
                )
                result.success(null)
            }
            "stop" -> {
                controller.stop()
                result.success(null)
            }
            "getLogs" -> result.success(controller.recentLogs(call.argument<Int>("lines") ?: 500))
            "getLogSnapshot" -> result.success(controller.logSnapshot((call.argument<Int>("lines") ?: 300).coerceIn(0, 2000)))
            "reset" -> controller.reset(ResetKeep.fromWire(call.argument<List<String>>("keep").orEmpty())) { error ->
                if (error == null) result.success(null) else result.error("reset_failed", error.message, null)
            }
            "lastKnownGood" -> controller.lastKnownGoodStatus { result.success(it) }
            "restoreLastKnownGood" -> controller.restoreLastKnownGood { plan, error ->
                if (error == null) result.success(plan) else result.error("restore_failed", error.message, null)
            }
            "safePreflight" -> controller.safePreflight { result.success(it) }
            "moveAside" -> controller.moveAside(call.argument<List<String>>("paths") ?: emptyList()) { moved, error ->
                if (error == null) result.success(moved) else result.error("move_failed", error.message, null)
            }
            "clearFailure" -> {
                controller.clearFailure()
                result.success(null)
            }
            "setAutoSafe" -> {
                controller.setAutoSafe(call.argument<Boolean>("enabled") != false)
                result.success(null)
            }
            "setDirectEngine" -> {
                try {
                    controller.setDirectEngine(call.argument<Boolean>("enabled") == true)
                    result.success(null)
                } catch (error: IllegalStateException) {
                    result.error("launch_method_unavailable", error.message, null)
                }
            }
            "failureLog" -> result.success(controller.failureLog())
            // ---- Linux 底座 P0：快照/回滚 + 状态采集（docs/LINUX_BASE_PLAN.md §6） ----
            "baseStats" -> result.success(RuntimeStats.collect(appContext))
            "resetSystem" -> {
                // 重置系统（2026-11-09）：清 rootfs 回未安装态；快照保留可回滚。
                Thread {
                    try {
                        appContext.startService(
                            Intent(appContext, DshService::class.java).setAction(DshService.ACTION_STOP),
                        )
                        Thread.sleep(600)
                        val rootfs = SnapshotManager.rootfsOf(appContext)
                        val retired = File(rootfs.parentFile, "runtime.reset.reset")
                        if (retired.exists()) retired.deleteRecursively()
                        if (rootfs.exists()) rootfs.renameTo(retired)
                        retired.deleteRecursively()
                        File(rootfs.parentFile, "rootfs.version").delete()
                        controller.onSystemReset()
                        result.success(true)
                    } catch (t: Throwable) {
                        result.success(false)
                    }
                }.start()
            }
            "snapshotList" -> result.success(
                SnapshotManager.list(appContext).map {
                    mapOf("name" to it.name, "createdAt" to it.createdAt, "bytes" to it.bytes, "note" to it.note)
                },
            )
            "snapshotProgress" -> {
                val p = SnapshotManager.progress
                result.success(if (p == null) null else mapOf("done" to p.first, "total" to p.second))
            }
            "snapshotCreate" -> {
                val note = call.argument<String>("note")
                Thread {
                    try {
                        val name = SnapshotManager.create(appContext, note)
                        val snap = SnapshotManager.list(appContext).firstOrNull { it.name == name }
                        result.success(mapOf("name" to name, "bytes" to (snap?.bytes ?: -1L), "error" to null))
                    } catch (t: Throwable) {
                        result.success(mapOf("name" to null, "bytes" to -1L, "error" to (t.message ?: t.javaClass.simpleName)))
                    }
                }.start()
            }
            "snapshotDelete" -> {
                val name = call.argument<String>("name") ?: return result.error("bad_arg", "name required", null)
                Thread {
                    result.success(SnapshotManager.delete(appContext, name))
                }.start()
            }
            "snapshotRestore" -> {
                val name = call.argument<String>("name") ?: return result.error("bad_arg", "name required", null)
                Thread {
                    try {
                        // 回滚前停系统（runtime.reset 语义沿用：旧 rootfs 挪退役目录）
                        appContext.startService(
                            Intent(appContext, DshService::class.java).setAction(DshService.ACTION_STOP),
                        )
                        Thread.sleep(800) // 给前台服务收尾留时隙
                        SnapshotManager.restore(appContext, name)
                        result.success(mapOf("ok" to true, "error" to null))
                    } catch (t: Throwable) {
                        result.success(mapOf("ok" to false, "error" to (t.message ?: t.javaClass.simpleName)))
                    }
                }.start()
            }
            "batteryExempt" -> {
                val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(appContext.packageName))
            }
            "requestBatteryExempt" -> result.success(requestBatteryExempt())
            "backgroundSettings" -> result.success(
                mapOf(
                    "vendor" to VendorSettings.vendorOf(Build.MANUFACTURER, Build.BRAND),
                    "label" to appContext.applicationInfo.loadLabel(appContext.packageManager).toString(),
                ),
            )
            "openBackgroundSettings" -> result.success(openVendorSettings(VendorSettings.Switch.BACKGROUND))
            "openVendorSettings" -> result.success(
                openVendorSettings(VendorSettings.Switch.parse(call.argument<String>("switch")) ?: VendorSettings.Switch.BACKGROUND),
            )
            "networkMetered" -> result.success(networkMetered())
            "voiceModelLine" -> {
                DshService.setVoiceLine(appContext, call.argument<String>("text"), call.argument<Int>("progress"))
                result.success(null)
            }
            "storageStatus" -> result.success(PhoneStorage.status(appContext))
            "requestStorage" -> requestStorage(result)
            "openAllFilesAccess" -> {
                val intent = PhoneStorage.allFilesAccessIntent(appContext)
                if (intent != null) runCatching { appContext.startActivity(intent) }
                result.success(intent != null)
            }
            else -> result.notImplemented()
        }
    }

    /** The system's "ignore battery optimizations" dialog, else the closest settings page that opens. */
    private fun requestBatteryExempt(): Boolean {
        val packageUri = Uri.parse("package:${appContext.packageName}")
        val host = activity?.activity
        for (intent in listOf(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, packageUri),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri),
        )) {
            val started = runCatching {
                if (host != null) host.startActivity(intent)
                else appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }.isSuccess
            if (started) return true
        }
        return false
    }

    /**
     * The vendor's own page for [switch] when one resolves, else this app's system details page:
     * `vendor`, `details`, or null when neither opened.
     */
    private fun openVendorSettings(switch: VendorSettings.Switch): String? {
        val pm = appContext.packageManager
        val packageName = appContext.packageName
        val host = activity?.activity
        fun launch(intent: Intent): Boolean = runCatching {
            if (host != null) host.startActivity(intent)
            else appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
        val vendor = VendorSettings.vendorOf(Build.MANUFACTURER, Build.BRAND)
        for (page in VendorSettings.pages(vendor, switch)) {
            val cls = page.cls
            val intent = if (cls != null) {
                Intent().setComponent(ComponentName(page.pkg, cls))
            } else {
                Intent(page.action ?: continue).setPackage(page.pkg)
            }
            page.packageExtra?.let { intent.putExtra(it, packageName) }
            page.labelExtra?.let { intent.putExtra(it, appContext.applicationInfo.loadLabel(pm).toString()) }
            val info = runCatching { intent.resolveActivityInfo(pm, 0) }.getOrNull()
            if (info?.exported != true) continue
            if (cls == null) intent.setClassName(info.packageName, info.name)
            if (launch(intent)) return "vendor"
        }
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        return if (launch(details)) "details" else null
    }

    /** Whether the active network is metered (mobile data, a metered hotspot); null when unknown. */
    private fun networkMetered(): Boolean? = runCatching {
        val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        if (cm.activeNetwork == null) null else cm.isActiveNetworkMetered
    }.getOrNull()

    /** Asks for READ/WRITE_EXTERNAL_STORAGE; answers with the resulting status map. */
    private fun requestStorage(result: MethodChannel.Result) {
        if (PhoneStorage.isGranted(appContext)) return result.success(PhoneStorage.status(appContext))
        val host: Activity = activity?.activity ?: return result.error("no_activity", "no foreground activity", null)
        pendingStorageResult?.success(PhoneStorage.status(appContext))
        pendingStorageResult = result
        host.requestPermissions(
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
            STORAGE_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != STORAGE_REQUEST) return false
        pendingStorageResult?.success(PhoneStorage.status(appContext))
        pendingStorageResult = null
        return true
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink?.let { controller.removeSink(it) }
        val s = RuntimeController.EventSink { events.success(it) }
        sink = s
        controller.addSink(s)
        events.success(mapOf("type" to "status", "status" to controller.status()))
    }

    override fun onCancel(arguments: Any?) {
        sink?.let { controller.removeSink(it) }
        sink = null
    }

    companion object {
        private const val STORAGE_REQUEST = 0x5d5
    }
}
