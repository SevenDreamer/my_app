// 版权来源：DSHA（MIT）com.deepseekharness.app.util.SensitiveData —— 现代化重构，行为契约不变。
//! 日志脱敏：把会泄露到 logcat / 活动日志的敏感值打码。
//! 覆盖私钥块、敏感头、查询凭据、常见键值、URL 用户信息、Bearer 和常见令牌。
//! 原生凭据持有者还可登记有界已知密钥；规则及边界由测试锁定。
//! 任意自定义头、非常规 JSON 字段及未登记秘密不保证可识别。
library;

/// 脱敏规则（顺序敏感：已知密钥优先，长密钥优先于短密钥）。
final List<RegExp> _rules = [
  RegExp(
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    dotAll: true,
  ),
  RegExp(
    r'((?:authorization|proxy-authorization|cookie|set-cookie|x-token)\s*:\s*)[^\r\n]+',
    multiLine: true,
    caseSensitive: false,
  ),
  RegExp(
    r'''([?&](?:token|api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|auth|secret|password|code|state|authorization_code|code_verifier|code_challenge|authorize_id)=)[^\s&#'"<>]+''',
    caseSensitive: false,
  ),
  RegExp(
    r'''(\b(?:[A-Z0-9_]*API_KEY|api[_-]?key|authorization|cookie|access[_-]?token|refresh[_-]?token|id[_-]?token|token|password|passwd|secret|code_verifier|code_challenge|authorization_code|authorize_id)\b["']?\s*[:=：]\s*)(?:"[^"]*"|'[^']*'|[^\s,;<>&#]+)''',
    caseSensitive: false,
  ),
  RegExp(r'(https?://)[^\s/@:]+:[^\s/@]+@', caseSensitive: false),
  RegExp(r'\bBearer\s+[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
  RegExp(
    r'\b(?:sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|xox[abpr]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\b',
  ),
];

const List<String> _replacements = [
  '[私钥已隐藏]', // 私钥整块
  r'$1***', // 敏感头
  r'$1***', // 查询凭据
  r'$1***', // 键值凭据
  r'$1***@', // URL 用户信息
  'Bearer ***',
  '***', // 令牌字面量
];

final Set<String> _known = <String>{};

/// 仅受信的原生凭据持有者登记密钥；内存有界（32 条，LRU 淘汰），可注销。
void registerKnownSecret(String value) {
  if (value.length < 8 || value.length > 4096) return;
  _known.remove(value);
  _known.add(value);
  while (_known.length > 32) {
    _known.remove(_known.first);
  }
}

/// 注销已登记密钥。
void forgetKnownSecret(String value) {
  _known.remove(value);
}

/// 脱敏入口：已知密钥（长者优先）→ 七条规则依序打码。
String redact(String value) {
  var safe = value;
  final known = _known.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final secret in known) {
    safe = safe.replaceAll(secret, '***');
  }
  for (var i = 0; i < _rules.length; i++) {
    safe = safe.replaceAllMapped(_rules[i], (m) {
      // 每条规则只回填第 1 个捕获组（与原版 replaceAll("$1***") 语义一致）。
      final prefix = (m.groupCount >= 1 ? m.group(1) : null) ?? '';
      final replacement = _replacements[i];
      if (replacement == '***' || replacement == 'Bearer ***') return replacement;
      return replacement.replaceFirst(r'$1', prefix);
    });
  }
  return safe;
}
