// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenTouchFeedback —— 现代化重构，行为契约不变。
//! 反馈仅主线程持有；它从不提交或重放任何输入。
//! 「Worker-side ordering: once failed/terminal, queued UP can never become another submission.」
library;

/// 反馈更新（原版 `Update`）。
enum TouchFeedbackUpdate { none, failed, completed }

/// 触摸票据（原版 `Ticket`）。
class TouchTicket {
  TouchTicket(this.viewEpoch, this.runEpoch, this.generation, this.sequence, this.stroke);

  final int viewEpoch, runEpoch, sequence;
  final String generation, stroke;
  bool failed = false, finished = false;
}

/// 派发序（原版 `Dispatch`）：已失败/终结后排队的 UP 永远不能再变成一次提交。
class TouchDispatch {
  bool _done = false;

  bool allowed() => !_done;

  /// 返回 true = 需要补发 CANCEL（失败且非 CANCEL 动作）。
  bool complete(int action, bool accepted) {
    if (_done) return false;
    _done = !accepted || action == 1 || action == 3;
    return !accepted && action != 3;
  }

  bool done() => _done;

  void abandon() {
    _done = true;
  }
}

/// 触摸反馈属主（原版 `VirtualScreenTouchFeedback`）。
class VscreenTouchFeedback {
  int _revision = 0;
  TouchTicket? _active;

  int revision() => _revision;

  int invalidate() {
    _active = null;
    return ++_revision;
  }

  void generation(String generation) {
    final active = _active;
    if (active != null && active.generation != generation) invalidate();
  }

  TouchTicket begin(
      int viewEpoch, int runEpoch, String generation, int sequence, String stroke) {
    invalidate();
    return _active = TouchTicket(viewEpoch, runEpoch, generation, sequence, stroke);
  }

  TouchTicket? find(String generation, int sequence, String stroke) {
    final active = _active;
    return active != null &&
            active.sequence == sequence &&
            active.generation == generation &&
            active.stroke == stroke
        ? active
        : null;
  }

  TouchFeedbackUpdate receipt(TouchTicket ticket, int viewEpoch, int runEpoch,
      String generation, bool ok, bool terminal) {
    if (!identical(ticket, _active) ||
        ticket.viewEpoch != viewEpoch ||
        ticket.runEpoch != runEpoch ||
        ticket.generation != generation ||
        ticket.sequence <= 0 ||
        ticket.failed ||
        ticket.finished) {
      return TouchFeedbackUpdate.none;
    }
    if (!ok) {
      ticket.failed = true;
      return TouchFeedbackUpdate.failed;
    }
    if (!terminal) return TouchFeedbackUpdate.none;
    ticket.finished = true;
    return TouchFeedbackUpdate.completed;
  }
}
