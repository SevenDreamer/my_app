//! Linux 底座引擎：系统状态采集（P0，见 docs/LINUX_BASE_PLAN.md §6）。
//!
//! 直读 /proc 与文件系统（不经 proot）：负载 / 内存 / rootfs 占用 /
//! 底座相关进程列表 / proot 运行时长。rootfs 大小递归较贵，结果缓存 30s。
package com.example.my_app.runtime

import android.content.Context
import java.io.File

object RuntimeStats {

    @Volatile
    private var diskCache: Pair<Long, Long>? = null // (bytes, sampledAt)

    /** 采集一次状态（map 直通 Dart 侧；缺项返回 null 字段而非抛错）。 */
    fun collect(context: Context): Map<String, Any?> {
        val rootfs = SnapshotManager.rootfsOf(context)
        return mapOf(
            "load1" to readLoad(),
            "memTotalMb" to memInfo("MemTotal"),
            "memAvailableMb" to memInfo("MemAvailable"),
            "rootfsBytes" to rootfsBytes(rootfs),
            "processes" to processes(),
            "prootUptimeSec" to prootUptimeSec(),
        )
    }

    private fun readLoad(): Double? =
        runCatching { File("/proc/loadavg").readText().split(" ").first().toDouble() }.getOrNull()

    private fun memInfo(key: String): Long? = runCatching {
        File("/proc/meminfo").readLines()
            .firstOrNull { it.startsWith("$key:") }
            ?.trim()?.split(Regex("\\s+"))?.get(1)?.toLongOrNull()?.div(1024) // kB → MB
    }.getOrNull()

    private fun rootfsBytes(rootfs: File): Long {
        val cached = diskCache
        val now = System.currentTimeMillis()
        if (cached != null && now - cached.second < 30_000) return cached.first
        var sum = 0L
        fun rec(d: File) {
            val ch = d.listFiles() ?: return
            for (f in ch) {
                if (java.nio.file.Files.isSymbolicLink(f.toPath())) continue
                if (f.isDirectory) rec(f) else sum += f.length()
            }
        }
        if (rootfs.isDirectory) rec(rootfs)
        diskCache = sum to now
        return sum
    }

    /** 底座相关进程：proc 下各 pid 的 cmdline 含 proot / dsh / node 的进程（短名+pid）。 */
    private fun processes(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val proc = File("/proc")
        for (p in proc.listFiles() ?: return emptyList()) {
            val pid = p.name.toIntOrNull() ?: continue
            val cmd = runCatching { File(p, "cmdline").readText() }.getOrNull() ?: continue
            val first = cmd.split('\u0000').firstOrNull()?.substringAfterLast('/') ?: continue
            if (first.startsWith("proot") || first.startsWith("dsh") || first.startsWith("node")) {
                out += mapOf("name" to first, "pid" to pid)
            }
        }
        return out
    }

    /** proot 主进程运行时长（/proc/<pid>/starttime 时钟滴答换算；无进程返回 null）。 */
    private fun prootUptimeSec(): Long? {
        val hz = 100.0 // USER_HZ 常见值；够用（秒级展示）
        val bootMs = android.os.SystemClock.elapsedRealtime()
        val proc = File("/proc")
        for (p in proc.listFiles() ?: return null) {
            val cmd = runCatching { File(p, "cmdline").readText() }.getOrNull() ?: continue
            if (!cmd.startsWith("proot")) continue
            val stat = runCatching { File(p, "stat").readText() }.getOrNull() ?: continue
            // stat 第 22 字段是 starttime（comm 可能含空格，从最后一个 ')' 后切）
            val tail = stat.substringAfterLast(')').trim().split(Regex("\\s+"))
            val startTicks = tail.getOrNull(19)?.toLongOrNull() ?: continue
            val sinceBootSec = startTicks / hz
            val uptime = bootMs / 1000.0
            return (uptime - sinceBootSec).toLong().coerceAtLeast(0)
        }
        return null
    }
}
