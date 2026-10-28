// 版权来源：DSHA（MIT）com.deepseekharness.app.util.CoalescingPoller —— 现代化重构，行为契约不变。
//! 一份延迟生产者由有界的属主集合共享；不按帧增长任务或线程。
//! 错误契约（逐字）：`POLL_LIMIT`/`POLL_OWNER_LIMIT`。
library;

/// 合并轮询订阅（原版 `CoalescingPoller.Subscription`）。
class PollSubscription<T> {
  PollSubscription._(this._poller, this.owner, this.listener);

  final CoalescingPoller<T> _poller;
  final Object owner;
  final void Function(T value) listener;
  bool _closed = false;

  bool closed() => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _poller._remove(this);
  }
}

/// 合并轮询（原版 `CoalescingPoller`）。
class CoalescingPoller<T> {
  CoalescingPoller({
    required this.producer,
    required this.maximumOwners,
    required this.delayMs,
    required this.schedule,
  }) {
    if (maximumOwners < 1 || delayMs < 1) throw ArgumentError('POLL_LIMIT');
  }

  final T? Function() producer;
  final int maximumOwners;
  final int delayMs;

  /// 周期任务缝（原版 `worker.scheduleWithFixedDelay`）；返回取消柄。
  final Object Function(void Function() poll, int delayMs) schedule;

  final Map<Object, PollSubscription<T>> _owners = {};
  Object? _scheduled;
  int _scheduleRevision = 0;

  void _remove(PollSubscription<T> subscription) {
    if (identical(_owners[subscription.owner], subscription)) {
      _owners.remove(subscription.owner);
    }
    if (_owners.isEmpty && _scheduled != null) {
      _cancel(_scheduled!);
      _scheduled = null;
      _scheduleRevision++;
    }
  }

  void Function(Object handle)? onCancel;

  void _cancel(Object handle) => onCancel?.call(handle);

  PollSubscription<T> subscribe(Object owner, void Function(T value) listener) {
    final old = _owners[owner];
    if (old != null) old.close();
    if (_owners.length >= maximumOwners) throw StateError('POLL_OWNER_LIMIT');
    final next = PollSubscription._(this, owner, listener);
    _owners[owner] = next;
    if (_scheduled == null) {
      final revision = ++_scheduleRevision;
      _scheduled = schedule(() => poll(revision), delayMs);
    }
    return next;
  }

  /// 一次取样（原版 `poll`）：失败静默；单个消费者异常不挡其他属主。
  void poll(int revision) {
    List<PollSubscription<T>> recipients;
    if (revision != _scheduleRevision || _owners.isEmpty) return;
    recipients = List.of(_owners.values);
    T? value;
    try {
      value = producer();
    } catch (unavailable) {
      return;
    }
    for (final recipient in recipients) {
      if (!recipient._closed) {
        try {
          recipient.listener(value as T);
        } catch (isolatedConsumer) {
          // Other live owners still receive this frame.
        }
      }
    }
  }
}
