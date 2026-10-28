// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenInputPolicy / VirtualScreenInputResult —— 现代化重构，行为契约不变。
//! 虚拟屏输入后端的纯逻辑：探测结论、后端选择、回退命令参数。
//! 两条后端不是等价替换：`reflection` 直接提交事件、逐事件生效；
//! `input-command` 一次手势在抬起时用 `input -d <displayId> tap|swipe` 重放，
//! 移动的中间态对界面不可见。
library;

/// 输入策略面（原版 `VirtualScreenInputPolicy`）。
abstract final class VscreenInputPolicy {
  /// 回退后端使用的系统命令；`/vscreen/type` 一直走的就是它。
  static const String command = '/system/bin/input';

  static const String backendReflection = 'reflection';
  static const String backendCommand = 'input-command';
  static const String backendUnavailable = 'unavailable';

  /// 反射后端需要的三个隐藏成员，按查找顺序排列（查找顺序＝真实失败顺序）。
  static const String memberGetInstance = 'InputManager.getInstance';
  static const String memberInjectEvent = 'InputManager.injectInputEvent(InputEvent,int)';
  static const String memberSetDisplay = 'InputEvent.setDisplayId(int)';

  /// 两条后端都不可用时的稳定码：虚拟屏能看，但不能注入输入。
  static const String inputUnavailable = 'VSCREEN_INPUT_UNAVAILABLE';

  static const int minDurationMs = 1;
  static const int maxDurationMs = 3000;

  /// 回退命令的超时预算下限（命令本身的启动开销）与上限。
  static const int commandMinTimeoutMs = 2500;
  static const int commandMaxTimeoutMs = 6000;

  /// 缺失/不可用的隐藏成员清单（按查找顺序、逗号分隔）；空串表示反射后端可用。
  ///
  /// `getInstance` 分「查不到」与「查得到但调用不成立」两态：后者在较新的系统上
  /// 是因为它改成了需要 ActivityThread 上下文，清单里必须写成不同的一项。
  static String missing(
      bool getInstanceFound, bool getInstanceCallable, bool injectEvent, bool setDisplay) {
    final out = StringBuffer();
    if (!getInstanceFound) {
      _append(out, memberGetInstance);
    } else if (!getInstanceCallable) {
      _append(out, '$memberGetInstance(invoke-failed)');
    }
    if (!injectEvent) {
      _append(out, memberInjectEvent);
    }
    if (!setDisplay) {
      _append(out, memberSetDisplay);
    }
    return out.toString();
  }

  /// 回退命令的超时预算：按住越久命令本身跑得越久，但上限必须远小于心跳预算
  /// （core 的 route 是类锁，一次手势会把 ping/status 串行化在后面），否则会被误判成 core 不可达。
  static int commandTimeoutMs(int gestureMs) {
    final budget = gestureMs + 2500;
    return budget < commandMinTimeoutMs
        ? commandMinTimeoutMs
        : (budget > commandMaxTimeoutMs ? commandMaxTimeoutMs : budget);
  }

  /// 后端选择：三个隐藏成员都在才用反射；否则退到 `input` 命令；命令也没有就是
  /// 没有后端——此时虚拟屏仍应创建成功，只是不能注入输入。
  static String backend(
      bool getInstance, bool injectEvent, bool setDisplay, bool commandAvailable) {
    if (getInstance && injectEvent && setDisplay) return backendReflection;
    return commandAvailable ? backendCommand : backendUnavailable;
  }

  /// 点击：`input -d <displayId> tap x y`。
  static List<String> tapArgs(int displayId, double x, double y) =>
      [command, '-d', '$displayId', 'tap', coordinate(x), coordinate(y)];

  /// 滑动：`input -d <displayId> swipe x1 y1 x2 y2 ms`。
  static List<String> swipeArgs(int displayId, double x1, double y1, double x2,
          double y2, int ms) =>
      [
        command,
        '-d',
        '$displayId',
        'swipe',
        coordinate(x1),
        coordinate(y1),
        coordinate(x2),
        coordinate(y2),
        '${duration(ms)}',
      ];

  /// 按键：`input -d <displayId> keyevent <code>`。
  static List<String> keyArgs(int displayId, int keycode) =>
      [command, '-d', '$displayId', 'keyevent', '$keycode'];

  /// 一次手势是否算点击：按下到抬起没有位移。
  static bool isTap(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1, dy = y2 - y1;
    return dx * dx + dy * dy < 4;
  }

  /// `input swipe` 的时长：0 会被命令拒绝，超上限按上限截断。
  static int duration(int ms) =>
      ms < minDurationMs ? minDurationMs : (ms > maxDurationMs ? maxDurationMs : ms);

  /// 命令参数里的坐标：向下取一位小数、固定小数点，非有限值退 0。
  ///
  /// 必须向下取整：core 用 `n < edge` 校验，四舍五入会把 1007.96 变成正好等于
  /// 显示边缘的 1008.0，命令侧收到越界坐标。argv 里必须是 `.`。
  static String coordinate(double value) {
    if (!value.isFinite) return '0.0';
    final floored = (value < 0 ? 0 : value) * 10;
    return '${(floored.floorToDouble() / 10).toStringAsFixed(1)}';
  }

  static void _append(StringBuffer out, String name) {
    if (out.isNotEmpty) out.write(',');
    out.write(name);
  }
}

/// 输入提交结果；已经提交后的失败不得被当成可以重放的前置拒绝。
/// 枚举值取原版大写名（与 `accepted()` 方法名不冲突，线格式同名）。
enum VscreenInputResult {
  REJECTED,
  ACCEPTED,
  UNKNOWN;

  static VscreenInputResult after(VscreenInputResult previous, VscreenInputResult next) {
    if (previous == VscreenInputResult.UNKNOWN || next == VscreenInputResult.UNKNOWN) {
      return VscreenInputResult.UNKNOWN;
    }
    if (previous == VscreenInputResult.ACCEPTED && next == VscreenInputResult.REJECTED) {
      return VscreenInputResult.UNKNOWN;
    }
    return next;
  }

  bool accepted() => this == VscreenInputResult.ACCEPTED;
}
