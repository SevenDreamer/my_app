//! Linux 底座：运行时镜像来源（2026-11-09，镜像上 R2——APK 不再内置 rootfs）。
//!
//! 解析顺序：assets 内置（老包/过渡期）→ 本地缓存（filesDir/runtime/cache）
//! → R2 镜像仓下载（my_app_dist/runtime/<abi>/…）。manifest 同规则。
//! 下载流式落盘 + 原子 rename，重复安装复用缓存；sha256 校验仍由
//! RuntimeInstaller 的既有链执行（本件只管把字节弄到手）。
package com.example.my_app.runtime

import android.content.Context
import android.content.res.AssetManager
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

object RuntimeImageSource {

    /** R2 公开镜像仓（公开桶非秘密；换桶改这一处）。 */
    const val MIRROR_BASE =
        "https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist/runtime"

    /** rootfs/manifest 所属 ABI 目录名（arm64-v8a | x86_64）。 */
    fun abi(): String {
        val primary = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        return when {
            primary.startsWith("arm64") -> "arm64-v8a"
            primary.startsWith("x86_64") -> "x86_64"
            else -> primary
        }
    }

    private fun cacheDir(context: Context): File =
        File(context.filesDir, "runtime/cache").apply { mkdirs() }

    private fun hasAsset(context: Context, path: String): Boolean = try {
        context.assets.openFd(path).close()
        true
    } catch (_: Throwable) {
        try {
            context.assets.open(path, AssetManager.ACCESS_STREAMING).close()
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** manifest 文本：assets 优先 → 缓存 → 下载（阻塞，调用方放后台）。 */
    fun manifestText(context: Context): String {
        val assetPath = "${RuntimeManifest.ASSET_DIR}/manifest.json"
        if (hasAsset(context, assetPath)) {
            return context.assets.open(assetPath).bufferedReader().use { it.readText() }
        }
        val cached = File(cacheDir(context), "manifest-${abi()}.json")
        if (cached.isFile && cached.length() > 0) return cached.readText()
        val tmp = File(cached.parentFile, cached.name + ".part")
        download("$MIRROR_BASE/${abi()}/manifest.json", tmp) { _, _ -> }
        if (!tmp.renameTo(cached)) throw IOException("manifest cache move failed")
        return cached.readText()
    }

    /** rootfs 来源（bytes 供进度分母；openStream 每次给新流——可重复读）。 */
    class RootfsSource(
        val bytes: Long,
        val fromAssets: Boolean,
        private val assetPath: String?,
        private val cacheFile: File?,
        private val context: Context,
    ) {
        fun openStream(): InputStream =
            if (fromAssets) context.assets.open(assetPath!!, AssetManager.ACCESS_STREAMING)
            else cacheFile!!.inputStream()
    }

    /**
     * 解析 rootfs 来源（可能触发下载，阻塞调用）；[onProgress] 报下载进度。
     * [assetName] 即 manifest 的 rootfs 字段（如 rootfs-arm64-v8a.tar.xz）。
     */
    fun rootfs(
        context: Context,
        assetName: String,
        onProgress: (Long, Long) -> Unit,
    ): RootfsSource {
        val assetPath = "${RuntimeManifest.ASSET_DIR}/$assetName"
        if (hasAsset(context, assetPath)) {
            val len = try {
                context.assets.openFd(assetPath).length
            } catch (_: Throwable) {
                -1L
            }
            return RootfsSource(len, true, assetPath, null, context)
        }
        val cached = File(cacheDir(context), assetName)
        if (cached.isFile && cached.length() > 0) {
            return RootfsSource(cached.length(), false, null, cached, context)
        }
        val tmp = File(cached.parentFile, "$assetName.part")
        download("$MIRROR_BASE/${abi()}/$assetName", tmp, onProgress)
        if (!tmp.renameTo(cached)) throw IOException("rootfs cache move failed")
        return RootfsSource(cached.length(), false, null, cached, context)
    }

    /** 流式下载（.part 临时文件 + rename 原子落位）；重复调用直接覆盖。
     *  网络必须离主线程（StrictMode 的 NetworkOnMainThreadException，2026-11-09
     *  实证：manifest 走 R2 后在 MethodChannel 主线程触碰即炸）——必要时自起
     *  工作线程并等待（manifest 仅 KB 级无感；rootfs 下载所在 install 链本在
     *  服务工作线程）。 */
    private fun download(url: String, dest: File, onProgress: (Long, Long) -> Unit) {
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            var err: Throwable? = null
            val t = Thread({
                try {
                    download(url, dest, onProgress)
                } catch (e: Throwable) {
                    err = e
                }
            }, "runtime-image-dl")
            t.start()
            t.join()
            err?.let { throw it }
            return
        }
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 30_000
        conn.readTimeout = 60_000
        try {
            if (conn.responseCode != 200) throw IOException("HTTP ${conn.responseCode}: $url")
            val total = conn.contentLengthLong
            conn.inputStream.use { input ->
                dest.outputStream().use { out ->
                    val buf = ByteArray(256 * 1024)
                    var done = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        done += n
                        onProgress(done, total)
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
    }
}
