//! 核心模型（会话/消息最小面；按 API 模块扩展）。
library;

/// 会话摘要（DSH session 列表项最小面）。
class DshSessionSummary {
  const DshSessionSummary({required this.id, this.title, this.updatedAt});

  final String id;
  final String? title;
  final DateTime? updatedAt;

  static DshSessionSummary? fromJson(Map<String, Object?> json) {
    final id = json['id'] ?? json['sessionId'];
    if (id is! String) return null;
    return DshSessionSummary(
      id: id,
      title: json['title'] as String?,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
