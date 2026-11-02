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

    override fun execVirtualScreen(command: String?): String = run(command ?: "")

    private fun run(command: String): String {
        return try {
            val process = ProcessBuilder("sh", "-c", command)
                .redirectErrorStream(true)
                .start()
            val output = process.inputStream.bufferedReader().readText()
            process.waitFor(30, java.util.concurrent.TimeUnit.SECONDS)
            output
        } catch (e: Throwable) {
            "SHELL_EXEC_FAILED ${e.message ?: ""}"
        }
    }

    override fun destroy() {
        // UserService lifecycle end (contract: one-shot destroy).
    }
}
