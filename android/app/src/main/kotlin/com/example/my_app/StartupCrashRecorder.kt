package com.example.my_app

import android.content.Context
import java.io.File

// Native-layer startup crash capture (MY-APP-6 lesson: ContentProvider init
// crashes happen BEFORE Flutter/Sentry init, so they were invisible). We
// install an UncaughtExceptionHandler as early as possible and persist the
// crash to a local file; the Dart side reads and reports it on next launch.
object StartupCrashRecorder {
    private const val FILE_NAME = "startup_crash.log"
    private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        val dir = context.applicationContext.filesDir
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val text = buildString {
                    appendLine("thread=${thread.name}")
                    appendLine("time=${System.currentTimeMillis()}")
                    appendLine(throwable.toString())
                    for (el in throwable.stackTrace.take(40)) appendLine("  at $el")
                }
                File(dir, FILE_NAME).writeText(text)
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    /// Dart 侧启动时读取（读后即删，一次性补报）。
    fun consume(context: Context): String? {
        return try {
            val file = File(context.applicationContext.filesDir, FILE_NAME)
            if (!file.exists()) return null
            val text = file.readText()
            file.delete()
            text
        } catch (_: Throwable) {
            null
        }
    }
}
