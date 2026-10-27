// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ShellQuote —— 现代化重构，行为契约不变。
//! 把任意字符串安全地变成一个 shell 参数（POSIX 单引号法）。
//!
//! 这里是一条**安全边界**：插件名、仓库地址、路径这些值有相当一部分来自
//! 插件市场索引或用户输入，最终拼进 `bash -c` 的命令串跑进容器。
//! 转义写错一次，恶意或畸形条目就能在 rootfs 里执行任意命令。
//!
//! 单引号内除单引号本身外 shell 不做任何解释（`$`、反引号、`;`、换行、
//! 通配符全部按字面传递），所以只需正确处理单引号一个字符。
library;

/// POSIX 单引号包裹；null 给出空参数 `''` 而不抛异常——
/// 调用点多在拼命令串中间，空参数让命令自己失败并带可读输出。
String shellQuoteArg(String? value) {
  if (value == null) return "''";
  return "'${value.replaceAll("'", "'\\''")}'";
}
