//! DSH Web API 纯 Dart 客户端（架构设计参考 dsh-go 的分层：connection/mux/api，
//! 代码原创；AGPL 只学设计不抄码）。
//!
//! 分层：[DshConnection] 连接层（launch-token → 会话凭证 → HTTP + WS 双通道）→
//! [DshMux] 多路复用（一 socket 多逻辑流，帧协议 open/item/end/cancel/error）→
//! 各 API 模块（session/messages/files…按需补）。
//!
//! 无 Flutter 依赖（可单测）。
library;

export 'src/connection.dart';
export 'src/mux.dart';
export 'src/errors.dart';
export 'src/models.dart';
