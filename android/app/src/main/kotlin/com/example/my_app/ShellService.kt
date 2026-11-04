package com.example.my_app

import android.content.Context

// Shizuku UserService shell (ported contract from DSHA ShellService):
// runs as shell uid; exec / execVirtualScreen execute commands and return
// combined output. Behavior contract: returns output text; destroy() ends.
class ShellService : IShellService.Stub {
    constructor() : super()
    @androidx.annotation.Keep
    constructor(context: Context) : super() { packageContext = context }

    // RootShell 入口用（原版契约：SelfPackageIdentity 构造重载）。
    @androidx.annotation.Keep
    constructor(identity: com.example.my_app.util.SelfPackageIdentity) : super() {
        launchIdentity = identity
    }

    private var packageContext: Context? = null
    private var launchIdentity: com.example.my_app.util.SelfPackageIdentity? = null

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
                // 原版 executeArgv 契约：argv[0] 补 /system/bin 前缀 + 显式 PATH；
                // 输出 = 进程全量 + [EXIT=码] 尾标——Dart 握手 VscreenHandshake.started
                // 硬性要求 [EXIT=0]，缺尾标则每次启动必判结果未知（MY-APP-5/6 真因）。
                try {
                    val resolved = java.util.ArrayList(argv)
                    if (!resolved[0].startsWith("/")) resolved[0] = "/system/bin/" + resolved[0]
                    val process = ProcessBuilder(resolved)
                        .redirectErrorStream(true)
                        .apply { environment()["PATH"] = "/system/bin:/system/xbin:/sbin:/vendor/bin" }
                        .start()
                    android.util.Log.i("ShellService", "run: exec >> $resolved")
                    // --launch/--probe-exit 均为一次性命令（成功/失败都退出，launch 内置
                    // 8s 上限）；独立读线程防管道写满死锁，waitFor 30s 兜底（原版期限）。
                    val output = StringBuilder()
                    val pump =
                        Thread {
                                try {
                                    process.inputStream.bufferedReader().useLines { lines ->
                                        lines.forEach { output.append(it).append('\n') }
                                    }
                                } catch (_: Throwable) {
                                }
                            }
                            .apply {
                                isDaemon = true
                                start()
                            }
                    val finished = process.waitFor(30, java.util.concurrent.TimeUnit.SECONDS)
                    if (!finished) process.destroyForcibly()
                    pump.join(2000)
                    android.util.Log.i(
                        "ShellService",
                        "run: done >> exit=${if (finished) process.exitValue() else "timeout"}",
                    )
                    output.toString() +
                        (if (finished) "\n[EXIT=${process.exitValue()}]"
                        else "\n[EXIT=timeout]")
                } catch (e: Throwable) {
                    "SHELL_EXEC_FAILED ${e.message ?: ""}\n[EXIT=125]"
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


    // 只供原生授权后的 root 子进程调用；Binder exec 不能选择此分支（原版契约）。
    fun execAuthorizedSms(command: String, user: Int): String {
        val plan = com.example.my_app.util.DeviceShellPolicy.inspect(command)
        if (plan.kind != com.example.my_app.util.DeviceShellPolicy.Kind.SENSITIVE_READ) {
            return com.example.my_app.util.UiText.text("[POLICY_BLOCKED] 不是受支持的短信查询\n[EXIT=126]")
        }
        return try {
            val process = ProcessBuilder(com.example.my_app.util.SmsQuery.forUser(plan.argv, user))
                .redirectErrorStream(true)
                .start()
            val text = process.inputStream.bufferedReader().readText()
            process.waitFor()
            text
        } catch (e: Throwable) {
            "SHELL_EXEC_FAILED ${e.message ?: ""}"
        }
    }

    override fun destroy() {
        // UserService lifecycle end (contract: one-shot destroy).
    }
}
