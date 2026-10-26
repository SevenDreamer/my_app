//! 手柄链路抽象：手机以手柄身份接入主机（另一台手机，将来 PC）
//!
//! 语义是「输入外设上报」而非字节管道——与 device_link 的消息传输
//! （Wi-Fi P2P）分属两个方向，故独立成接口，不并入 DeviceTransport。
//! 一期实现：HID（packages/hid_gamepad）；二期反馈：GATT 富通道（震动）。
import 'gamepad_report.dart';

/// 手柄链路状态
enum GamepadLinkState {
  /// 未启动
  idle,

  /// 广播中（主机端可搜索/配对）
  advertising,

  /// 已连接（主机已认出，可上报输入）
  connected,

  /// 连接断开（仍可被重新连接）
  disconnected,
}

abstract class GamepadLink {
  /// 链路状态流
  Stream<GamepadLinkState> get state;

  /// 以手柄身份开始广播（主机端搜索/配对 [name]）
  Future<void> startAsGamepad({String name = 'my_app Gamepad'});

  /// 发送一帧输入报告（按键/摇杆；陀螺仪在调用前映射为轴值）
  Future<void> sendInputReport(GamepadReport report);

  /// 停止广播并释放资源
  Future<void> stop();
}
