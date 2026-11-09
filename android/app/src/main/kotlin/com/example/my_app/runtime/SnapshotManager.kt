//! Linux 底座引擎：快照/回滚（P0，见 docs/LINUX_BASE_PLAN.md §6）。
//!
//! 与 LastKnownGood 并存的显式快照：LKG 是自动「最后已知良好」，本件是
//! 用户手动快照。打包对象是解包后的 rootfs 目录（filesDir/runtime/rootfs），
//! 格式 tar.xz（与 rootfs 发行格式同族），存 filesDir/snapshots/。
package com.example.my_app.runtime

import android.content.Context
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream
import org.apache.commons.compress.compressors.xz.XZCompressorInputStream
import org.apache.commons.compress.compressors.xz.XZCompressorOutputStream
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.atomic.AtomicLong

object SnapshotManager {

    /** 单个快照的元数据（sidecar json 与列表项同构）。 */
    data class Snapshot(val name: String, val createdAt: Long, val bytes: Long, val note: String?)

    /** 打包/回滚进度：done 字节 / 总估算字节（总值以 rootfs 当前大小估算）。 */
    @Volatile
    var progress: Pair<Long, Long>? = null
        private set

    fun dir(context: Context): File = File(context.filesDir, "snapshots")

    /** rootfs 解包落点（与 RuntimeInstaller.rootfs 同一路径约定）。 */
    fun rootfsOf(context: Context): File = File(File(context.filesDir, "runtime"), "rootfs")

    private fun stamp(): String =
        java.text.SimpleDateFormat("yyyyMMdd-HHmmss", java.util.Locale.US).format(java.util.Date())

    /**
     * 打一个快照（同步执行，调用方放后台线程）。返回快照名；抛 [IOException]
     * 表示失败（部分文件会被清理）。
     */
    fun create(context: Context, note: String?): String {
        val rootfs = rootfsOf(context)
        if (!rootfs.isDirectory) throw IOException("rootfs missing: ${rootfs.path}")
        val name = "snap-${stamp()}"
        val out = File(dir(context).apply { mkdirs() }, "$name.tar.xz")
        val total = AtomicLong(0L)
        walk(rootfs) { total.addAndGet(it.length()) }
        val done = AtomicLong(0L)
        progress = 0L to total.get()
        try {
            TarArchiveOutputStream(XZCompressorOutputStream(out.outputStream().buffered(), 6)).use { tar ->
                tar.setLongFileMode(TarArchiveOutputStream.LONGFILE_POSIX)
                walkEntries(rootfs) { file, rel, isLink, linkTarget, mode ->
                    val entry = TarArchiveEntry(rel)
                    entry.mode = mode
                    if (isLink) {
                        entry.size = 0
                        entry.linkName = linkTarget
                    } else {
                        entry.size = file.length()
                    }
                    tar.putArchiveEntry(entry)
                    if (!isLink) {
                        file.inputStream().use { input ->
                            val buf = ByteArray(256 * 1024)
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                tar.write(buf, 0, n)
                                done.addAndGet(n.toLong())
                                progress = done.get() to total.get()
                            }
                        }
                    }
                    tar.closeArchiveEntry()
                }
            }
        } catch (t: Throwable) {
            out.delete()
            throw t
        } finally {
            progress = null
        }
        // sidecar 元数据（列表不依赖解析 tar）
        File(dir(context), "$name.json").writeText(
            """{"name":"$name","createdAt":${System.currentTimeMillis()},"bytes":${out.length()},"note":${jsonStr(note)}}"""
        )
        prune(context)
        return name
    }

    /** 快照列表（新→旧）。sidecar 缺失的 tar 也认（时间为文件 mtime）。 */
    fun list(context: Context): List<Snapshot> {
        val dir = dir(context)
        val files = dir.listFiles { f -> f.name.endsWith(".tar.xz") } ?: return emptyList()
        return files.map { f ->
            val base = f.name.removeSuffix(".tar.xz")
            val meta = File(dir, "$base.json")
            if (meta.isFile) {
                val t = meta.readText()
                Snapshot(base, jsonLong(t, "createdAt") ?: f.lastModified(), jsonLong(t, "bytes") ?: f.length(), jsonStrIn(t, "note"))
            } else {
                Snapshot(base, f.lastModified(), f.length(), null)
            }
        }.sortedByDescending { it.createdAt }
    }

    /**
     * 回滚到 [name]（同步执行，调用方放后台线程；系统须已停止）。
     * 旧 rootfs 挪到 runtime.reset（沿用退役目录语义），解包完成后落位。
     */
    fun restore(context: Context, name: String) {
        val dir = dir(context)
        val archive = File(dir, "$name.tar.xz")
        if (!archive.isFile) throw IOException("snapshot not found: $name")
        val rootfs = rootfsOf(context)
        val staging = File(rootfs.parentFile, "staging-snapshot")
        if (staging.exists()) staging.deleteRecursively()
        staging.mkdirs()
        val total = archive.length()
        val done = AtomicLong(0L)
        progress = 0L to total
        try {
            TarArchiveInputStream(XZCompressorInputStream(archive.inputStream().buffered())).use { tar ->
                while (true) {
                    val entry = tar.nextTarEntry ?: break
                    val out = File(staging, entry.name)
                    if (!out.canonicalPath.startsWith(staging.canonicalPath + File.separator)) {
                        throw IOException("entry escapes rootfs: ${entry.name}")
                    }
                    if (entry.isSymbolicLink) {
                        out.parentFile?.mkdirs()
                        try {
                            Files.createSymbolicLink(out.toPath(), File(entry.linkName).toPath())
                        } catch (_: Throwable) {
                            // 链接建不了就跳过（坏链容忍，与发行包语义一致）
                        }
                    } else if (entry.isDirectory) {
                        out.mkdirs()
                    } else {
                        out.parentFile?.mkdirs()
                        out.outputStream().use { o -> tar.copyTo(o) }
                        done.addAndGet(entry.size)
                        progress = done.get() to total
                    }
                }
            }
            // 落位：旧 rootfs 挪退役目录（可回收），新目录 rename 上位
            val retired = File(rootfs.parentFile, "runtime.reset.restore")
            if (retired.exists()) retired.deleteRecursively()
            if (rootfs.exists() && !rootfs.renameTo(retired)) {
                throw IOException("cannot move aside current rootfs")
            }
            if (!staging.renameTo(rootfs)) {
                // 回退：旧的挪回来
                retired.renameTo(rootfs)
                throw IOException("cannot place restored rootfs")
            }
            retired.deleteRecursively()
        } finally {
            progress = null
            if (staging.exists()) staging.deleteRecursively()
        }
    }

    fun delete(context: Context, name: String): Boolean {
        val dir = dir(context)
        val a = File(dir, "$name.tar.xz")
        val m = File(dir, "$name.json")
        val ok = a.delete()
        m.delete()
        return ok
    }

    /** 保留策略：最多 [KEEP] 个快照，旧的自动清（含 sidecar）。 */
    private const val KEEP = 3

    private fun prune(context: Context) {
        val all = list(context)
        for (s in all.drop(KEEP)) delete(context, s.name)
    }

    // ---- 遍历（symlink 不跟随；父先于子保证解包顺序无关——tar 本就按序） ----

    private fun walk(dir: File, onFile: (File) -> Unit) = walkEntries(dir) { f, _, isLink, _, _ ->
        if (!isLink) onFile(f)
    }

    private fun walkEntries(
        dir: File,
        onEntry: (file: File, rel: String, isLink: Boolean, linkTarget: String, mode: Int) -> Unit,
    ) {
        fun rec(d: File) {
            val children = d.listFiles() ?: return
            for (f in children) {
                val rel = f.relativeTo(dir).path.replace(File.separatorChar, '/')
                val isLink = Files.isSymbolicLink(f.toPath())
                if (isLink) {
                    val target = Files.readSymbolicLink(f.toPath()).toString()
                    onEntry(f, rel, true, target, 0b111_101_101) // lrwxrwxrwx 语义位（tar 内 symlink 常用 0777）
                } else if (f.isDirectory) {
                    onEntry(f, rel, false, "", 0b111_101_101)
                    rec(f)
                } else {
                    val mode = if (f.canExecute()) 0b111_101_101 else 0b110_100_100
                    onEntry(f, rel, false, "", mode)
                }
            }
        }
        rec(dir)
    }

    private fun jsonStr(s: String?): String =
        if (s == null) "null" else "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

    private fun jsonLong(t: String, key: String): Long? =
        Regex("\"$key\"\\s*:\\s*(\\d+)").find(t)?.groupValues?.get(1)?.toLongOrNull()

    private fun jsonStrIn(t: String, key: String): String? =
        Regex("\"$key\"\\s*:\\s*\"([^\"]*)\"").find(t)?.groupValues?.get(1)
}
