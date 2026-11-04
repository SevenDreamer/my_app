//! 错误面（协议错误代号语义：code/message/details 三元组，逐字透传不吞）。
library;

/// DSH Web API 错误（mux error 帧与 HTTP 错误体共用形态）。
class DshApiException implements Exception {
  const DshApiException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'DshApiException($code): $message';
}

/// 会话失效（HTTP 401 / WS ready 失败）——调用方应重登。
class DshUnauthorizedException extends DshApiException {
  const DshUnauthorizedException([String message = 'UNAUTHORIZED'])
      : super('UNAUTHORIZED', message);
}
