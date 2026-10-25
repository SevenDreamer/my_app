package com.example.my_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
