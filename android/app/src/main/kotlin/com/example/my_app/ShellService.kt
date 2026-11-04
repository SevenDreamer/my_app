package com.example.my_app

import android.content.Context

// Shizuku UserService shell (ported contract from DSHA ShellService):
// runs as shell uid; exec / execVirtualScreen execute commands and return
// combined output. Behavior contract: returns output text; destroy() ends.
class ShellService : IShellService.Stub {
    constructor() : super()
    @androidx.annotation.Keep
    constructor(context: Context) : super() { packageContext = context }

    private var packageContext: Context? = null

    override fun exec(cmd: String?): String = run(cmd ?: "")

    override fun execVirtualScreen(command: String?): String {
        // 契约（原版 DeviceShellExecutor.executeVirtualScreen）：uid 校验 +
        // SelfPackageIdentity 校验 + DeviceShellPolicy argv 策略——不得退化成
        // 任意 shell（channels.dart 契约注释）。Runner = argv 数组执行。
        val ctx = packageContext
        val identity = com.example.my_app.util.SelfPackageIdentity.launch(
            ctx?.packageName ?: "",
            android.os.Process.myUid(),
            ctx?.applicationInfo?.sourceDir ?: "",
            ctx?.applicationInfo?.sourceDir ?: ""
        ) ?: return "[POLICY_BLOCKED] SELF_PACKAGE_UNVERIFIED\n[EXIT=126]"
        return com.example.my_app.DeviceShellExecutor.executeVirtualScreen(
            command ?: "",
            { argv ->
                try {
                    val p = ProcessBuilder(argv)
                        .redirectErrorStream(true)
                        .start()
                    android.util.Log.i("ShellService", "run: exec >> $argv")
                    val reader = p.inputStream.bufferedReader()
                    val first = reader.readLine() ?: ""
                    android.util.Log.i("ShellService", "run: done >> '$first'")
                    first
                } catch (e: Throwable) {
                    "SHELL_EXEC_FAILED ${e.message ?: ""}"
                }
            },
            identity
        )
    }

    private fun run(command: String): String {
        return try {
            val process = ProcessBuilder("sh", "-c", command)
                .redirectErrorStream(true)
                .start()
            // core 是常驻进程（不退出、输出流不关）——原版契约：读到首个
            // 有效行（core 握手行）即返回，不等 EOF（否则 readText 死等，
            // MY-APP-5 execOutput 恒空实证）。
            android.util.Log.i("ShellService", "run: exec >> $command")
            val reader = process.inputStream.bufferedReader()
            var first = ""
            // 读首个非空行（core 握手行）；空行跳过（不等 EOF，core 常驻）。
            while (first.isEmpty()) {
                val line = reader.readLine() ?: break
                android.util.Log.i("ShellService", "run: line >> $line")
                first = line
            }
            android.util.Log.i("ShellService", "run: done >> '$first'")
            first
        } catch (e: Throwable) {
            "SHELL_EXEC_FAILED ${e.message ?: ""}"
        }
    }

    override fun destroy() {
        // UserService lifecycle end (contract: one-shot destroy).
    }
}
