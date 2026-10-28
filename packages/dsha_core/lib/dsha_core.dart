//! DSHA 重构核心包：安装流水线编排、备份/配置 API、兼容层。
//! 来源 DSHA（MIT）——各派生文件带归因头，汇总见仓库 THIRD_PARTY_NOTICES.md。
library;

export 'src/bridge/adb_bridge.dart';
export 'src/bridge/adb_virtual_screen_start.dart';
export 'src/bridge/bridge_connection_descriptor.dart';
export 'src/bridge/bridge_handshake.dart';
export 'src/install/install_pipeline.dart';
export 'src/install/install_probe.dart';
export 'src/install/install_process.dart';
export 'src/install/install_stage.dart';
export 'src/install/sensitive_data.dart';
export 'src/util/shell_quote.dart';
export 'src/vscreen/a11y_support.dart';
export 'src/vscreen/accessibility.dart';
export 'src/vscreen/bootstrap.dart';
export 'src/vscreen/core.dart';
export 'src/vscreen/core_identity.dart';
export 'src/vscreen/display_session.dart';
export 'src/vscreen/failures.dart';
export 'src/vscreen/input.dart';
export 'src/vscreen/input_policy.dart';
export 'src/vscreen/journal.dart';
export 'src/vscreen/observed_control.dart';
export 'src/vscreen/observed_pixels.dart';
export 'src/vscreen/peer_proof.dart';
export 'src/vscreen/pixels.dart';
export 'src/vscreen/policy.dart';
export 'src/vscreen/proc_identity.dart';
export 'src/vscreen/request_scope.dart';
export 'src/vscreen/stroke.dart';
export 'src/vscreen/support.dart';
export 'src/vscreen/target_evidence.dart';
export 'src/vscreen/vscreen_handshake.dart';
