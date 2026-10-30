package com.example.my_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Runtime channel: nativeLibraryDir is the only exec-allowed dir on
        // Android 10+ (W^X) — proot ships as jniLibs and runs from there.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_app/runtime")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                    "dataDir" -> result.success(applicationInfo.dataDir)
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
