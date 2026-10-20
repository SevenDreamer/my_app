//! 错误码表：E<类别><序号>——报错、日志、反馈统一用这套码
//!
//! 分段：E1xxx 网络 / E2xxx 授权 / E3xxx 更新下载 / E4xxx 存储 / E9xxx 未知。
//! 新增错误时按类别顺延序号，历史码不复用。
abstract class ErrorCodes {
  // ── E1xxx 网络 ──
  /// DNS 解析失败（如 Failed host lookup: "github.com"）
  static const String netDns = 'E1001';

  /// 连接超时 / 拒绝
  static const String netTimeout = 'E1002';

  /// 网络不可用
  static const String netUnavailable = 'E1003';

  /// 其他网络异常
  static const String netOther = 'E1099';

  // ── E2xxx 授权 ──
  /// 尚未授权
  static const String authNone = 'E2001';

  /// 授权过期 / 被撤销（API 401）
  static const String authExpired = 'E2002';

  /// 设备码申请失败
  static const String authDeviceCode = 'E2003';

  /// 授权轮询失败 / 超时
  static const String authPoll = 'E2004';

  /// refresh_token 续期失败
  static const String authRefresh = 'E2005';

  // ── E3xxx 更新 / 下载 ──
  /// 获取 Release 信息失败
  static const String updateRelease = 'E3001';

  /// 最新 Release 没有 Android 包
  static const String updateNoApk = 'E3002';

  /// 签名下载链接获取失败
  static const String updateSignedUrl = 'E3003';

  // ── E4xxx 存储 ──
  /// 本地凭证/日志存储异常
  static const String storage = 'E4001';

  // ── E9xxx 未知 ──
  /// 未分类异常（兜底）
  static const String unknown = 'E9000';

  /// 码所属类别名（错误框/日志展示用）
  static String categoryOf(String code) {
    if (code.startsWith('E1')) return '网络';
    if (code.startsWith('E2')) return '授权';
    if (code.startsWith('E3')) return '更新下载';
    if (code.startsWith('E4')) return '存储';
    return '未知';
  }
}
