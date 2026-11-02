package com.example.my_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

// Runtime keep-alive service (ported contract from DSHA's HarnessService):
// a persistent foreground notification lowers reclaim probability, and
// Android 8+ requires startForeground within 5s of startForegroundService.
class RuntimeForegroundService : Service() {
    companion object {
        const val ACTION_STOP = "com.example.my_app.RUNTIME_STOP"
        const val CHANNEL_ID = "dsha_runtime"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && ACTION_STOP == intent.action) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startForeground(1, buildNotification())
        } catch (e: Exception) {
            // Contract: failure to enter foreground within the deadline must
            // stop the service rather than leave a zombie (redacted message).
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "DSH 运行时", NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("DSH 运行时保持运行")
            .setContentText("虚拟屏与安装任务需要常驻运行")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .build()
    }
}
