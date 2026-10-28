// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenAccessibility —— 现代化重构，行为契约不变。
//! 所有查询和动作均限定在虚拟 displayId，不使用主屏的 activeWindow。
//! 错误契约（逐字）：`VSCREEN_UNSUPPORTED_LOW`/`VSCREEN_API_30_REQUIRED`/
//! `INVALID_NATIVE_NODE_OPERATION`/`NATIVE_CONTROL_REVOKED`/`SCREEN_TARGET_CHANGED`/
//! `ACCESSIBILITY_UNAVAILABLE`/`INVALID_DISPLAY`/`VIRTUAL_WINDOW_UNAVAILABLE`/
//! `ROOT_REFRESH_UNAVAILABLE`/`EMPTY_ACCESSIBILITY_TREE`/`STALE_TREE`/`STALE_NODE`/
//! `NATIVE_NODE_ACTION_UNAVAILABLE`/`INVALID_NATIVE_NODE_ACTION`/`TEXT_LIMIT`/
//! `INVALID_NODE_ACTION`/`NODE_ACTION_REJECTED`/`VIRTUAL_INPUT_NOT_FOCUSED`/
//! `PASSWORD_INPUT_UNAVAILABLE`/`EDITOR_CHANGED`/`IME_ACTION_UNAVAILABLE`/
//! `INVALID_EDITOR_OPERATION`/`INVALID_EDITOR_RANGE`/`EDITOR_WRITE_REJECTED`/
//! `VIRTUAL_INPUT_RESULT_UNKNOWN`/`ACCESSIBILITY_OPERATION_UNKNOWN`。
library;

import 'a11y_support.dart';
import 'support.dart';

/// 节点动作（语义名；真实 action id / Bundle 键由 Android 缝映射官方常量）。
enum A11yAction { click, longClick, scrollForward, scrollBackward, focus, setText, imeEnter, setSelection }

/// 无障碍节点句柄（缝：`AccessibilityNodeInfo`）。
abstract class A11yNode implements A11yNodeHandle {
  int get windowId;

  /// 原版 `hashCode()`（拼 editorId）。
  int nodeHash();

  /// 原版 `getPackageName()`。
  String packageName();

  String? rawText();

  String? contentDescription();

  VscreenRect boundsInScreen();

  bool isEnabled();

  bool isEditable();

  bool isPassword();

  bool isClickable();

  bool isScrollable();

  bool isMultiLine();

  int textSelectionStart();

  int textSelectionEnd();

  int inputType();

  /// `getActionList().contains(ACTION_SET_TEXT)`。
  bool supportsSetText();

  /// 原版 `performAction(action, args)`；args 语义键由缝翻译。
  bool performAction(A11yAction action, Map<String, Object?>? args);

  int childCount();

  A11yNode? child(int index);

  /// 原版 `findFocus(FOCUS_INPUT)`。
  A11yNode? findFocusInput();
}

/// 目标已变更（原版 `DshaAccessibilityService.TargetChangedException`）。
class TargetChanged implements Exception {}

/// 虚拟根/目标校验缝（原版 `DshaAccessibilityService` 静态面）。
abstract class VirtualRootApi {
  A11yNode? virtualRoot(int displayId);

  String windowDiagnostic();

  A11yNode? refreshVirtualRoot(int displayId, A11yNode? root);

  bool matchesTarget(ScreenTarget identity);

  void validateActionRoot(int displayId, A11yNode root);
}

/// 原生控制租约缝（原版 `NativeScreenControlLease`）。
abstract class NativeScreenControlLease {
  /// 非 null 才准入（原版 `lease.service()`）。
  Object? service();

  NativeActionHandle? begin(int displayId, ScreenTarget? target, bool tree);
}

abstract class NativeActionHandle {
  void validateRoot(int displayId, A11yNode root);

  void validateCurrentTarget();

  bool claimDispatch();

  bool current();

  bool mayHaveSubmitted();

  void close();
}

/// 原生回复信封缝（原版 `ScreenReply`/`CapabilityResult`）。
/// 失败判据契约：`mutation && mayHaveSubmitted` → unknown(`VIRTUAL_INPUT_RESULT_UNKNOWN`)
/// 否则 notSent(code)。
abstract class NativeReplyApi {
  Map<String, Object?> unavailable();

  Map<String, Object?> refused(String code);

  Map<String, Object?> failure(bool mutation, bool mayHaveSubmitted, String code);
}

/// 无障碍操作面（原版 `VirtualScreenAccessibility`）。
class VscreenAccessibility {
  VscreenAccessibility({
    required this.roots,
    required this.clock,
    NativeReplyApi? nativeReply,
    bool lowAndroid = false,
    int sdkInt = 30,
  })  : _nativeReply = nativeReply,
        _lowAndroid = lowAndroid,
        _sdkInt = sdkInt;

  final VirtualRootApi roots;
  final VscreenClock clock;
  final NativeReplyApi? _nativeReply;
  final bool _lowAndroid;
  final int _sdkInt;

  final Map<String, A11yNode> nodes = <String, A11yNode>{};
  int treeDisplay = -1;
  ScreenTarget? treeTarget;
  int treeAt = 0;
  VscreenObservedControlLike? _observed;

  /// 观察属主缝（原版 `VirtualScreenObservedControl`，D2 已移植）。
  VscreenObservedControlLike? observedOwner() => _observed;

  void attachObserved(VscreenObservedControlLike owner) => _observed = owner;

  /// 观察控制入口（原版 `observedControl`；click 走 ACTION_CLICK 守卫）。
  Map<String, Object?> observedControl(
    int displayId,
    String operation,
    Map<String, Object?> args,
    VscreenContext context,
    ObservedPixelsApi pixels,
  ) {
    if (_lowAndroid) return _fail('VSCREEN_UNSUPPORTED_LOW');
    if (_sdkInt < 30) return _fail('VSCREEN_API_30_REQUIRED');
    final owner = _observed;
    if (owner == null) return _fail('ACCESSIBILITY_UNAVAILABLE');
    return owner.run(displayId, operation, args, context, pixels,
        (node, root, request, submitted, leaseCurrent) {
      final guard = ActionGuard(request, displayId)..root = root as A11yNode;
      guard.leaseCurrent = leaseCurrent;
      return _perform(node as A11yNode, submitted, guard, A11yAction.click);
    });
  }

  void invalidateObserved() {
    if (_sdkInt >= 30) _observed?.invalidate();
  }

  void clearObserved() {
    if (_sdkInt >= 30) _observed?.clear();
  }

  /// 主入口（原版 `run`）。
  Map<String, Object?> run(
    int displayId,
    String operation,
    Map<String, Object?> args,
    VscreenContext? context, [
    NativeActionHandle? nativeAction,
  ]) {
    final guard = ActionGuard(context, displayId, nativeAction);
    A11yNode? root, target;
    final submitted = <bool>[false];
    try {
      if (operation == 'tree') clear();
      if (_sdkInt < 30 || displayId <= 0) return _fail('INVALID_DISPLAY');
      root = roots.virtualRoot(displayId);
      if (root == null) {
        clear();
        return _fail('VIRTUAL_WINDOW_UNAVAILABLE')
          ..put('treeUnavailable', roots.windowDiagnostic());
      }
      if (nativeAction != null) {
        nativeAction.validateRoot(displayId, root);
      } else if (context == null) {
        roots.validateActionRoot(displayId, root);
      } else {
        context.validateRoot(displayId, root);
      }
      guard.root = root;
      // 只读文本也是敏感的：已批请求在遍历前一次性消费。
      if (operation == 'tree' || operation == 'editor') guard.validate();
      if (operation == 'tree') {
        final tree = <Map<String, Object?>>[];
        var budget = AccessibilityTreeBudget();
        _walk(root, tree, 0, budget);
        var identity = ScreenTarget(displayId, root.windowId, root.packageName());
        if (tree.isEmpty) {
          // 一次只读刷新，仍绑定同一 display/window/package。
          final refreshed = roots.refreshVirtualRoot(displayId, root);
          root = refreshed;
          guard.root = root;
          if (context != null && root != null) context.validateRoot(displayId, root);
          if (nativeAction != null && root != null) nativeAction.validateRoot(displayId, root);
          if (root != null) {
            budget = AccessibilityTreeBudget();
            _walk(root, tree, 0, budget);
          }
        }
        if (root == null) {
          clear();
          return _fail('VIRTUAL_WINDOW_UNAVAILABLE')
            ..put('nodes', tree)
            ..put('treeUnavailable', 'ROOT_REFRESH_UNAVAILABLE');
        }
        if (!roots.matchesTarget(identity)) throw TargetChanged();
        final result = _ok()
          ..put('nodes', tree)
          ..put('visited', budget.visits());
        if (budget.exhausted()) result.put('truncated', true);
        if (tree.isEmpty) {
          clear();
          result.put('treeUnavailable', 'EMPTY_ACCESSIBILITY_TREE');
        } else {
          treeDisplay = displayId;
          treeTarget = identity;
          treeAt = clock.millis();
        }
        return result;
      }
      if (operation == 'node') {
        final current = ScreenTarget(displayId, root.windowId, root.packageName());
        if (displayId != treeDisplay ||
            treeTarget == null ||
            !treeTarget!.matches(current) ||
            clock.millis() - treeAt > 30000) {
          clear();
          return _fail('STALE_TREE');
        }
        target = nodes.remove(args.optString('nodeId'));
        if (target == null || !target.refresh() || target.windowId != root.windowId) {
          return _fail('STALE_NODE');
        }
        final action = args.optString('action');
        if (nativeAction != null &&
            (!target.isEnabled() ||
                (action == 'click' && !target.isClickable()) ||
                (action == 'set_text' && !target.supportsSetText()))) {
          return _fail('NATIVE_NODE_ACTION_UNAVAILABLE');
        }
        if (nativeAction != null && action != 'click' && action != 'set_text') {
          return _fail('INVALID_NATIVE_NODE_ACTION');
        }
        switch (action) {
          case 'click':
            return _finishPerform(
                _perform(target, submitted, guard, A11yAction.click));
          case 'long_click':
            return _finishPerform(
                _perform(target, submitted, guard, A11yAction.longClick));
          case 'scroll_forward':
            return _finishPerform(
                _perform(target, submitted, guard, A11yAction.scrollForward));
          case 'scroll_backward':
            return _finishPerform(
                _perform(target, submitted, guard, A11yAction.scrollBackward));
          case 'focus':
            return _finishPerform(
                _perform(target, submitted, guard, A11yAction.focus));
          case 'set_text':
            final value = args.optString('text');
            if (value.length > 16000) return _fail('TEXT_LIMIT');
            return _finishPerform(_perform(target, submitted, guard, A11yAction.setText, {
              'text': value,
            }));
          default:
            return _fail('INVALID_NODE_ACTION');
        }
      }
      target = root.findFocusInput();
      if (target == null || !target.isEditable()) return _fail('VIRTUAL_INPUT_NOT_FOCUSED');
      if (target.isPassword()) return _fail('PASSWORD_INPUT_UNAVAILABLE');
      final id = '${target.windowId}:${target.nodeHash()}';
      if (operation == 'editor') {
        return _ok()
          ..put('editorId', id)
          ..put('text', target.rawText() ?? '')
          ..put('start', target.textSelectionStart())
          ..put('end', target.textSelectionEnd())
          ..put('inputType', target.inputType())
          ..put('multiline', target.isMultiLine());
      }
      if (id != args.optString('editorId')) return _fail('EDITOR_CHANGED');
      if (operation == 'submit') {
        return _perform(target, submitted, guard, A11yAction.imeEnter)
            ? _ok()
            : _fail('IME_ACTION_UNAVAILABLE');
      }
      if (operation != 'edit') return _fail('INVALID_EDITOR_OPERATION');
      final text = args.optString('text');
      final start = args.optInt('start', text.length), end = args.optInt('end', start);
      if (text.length > 16000 ||
          start < 0 ||
          end < 0 ||
          start > text.length ||
          end > text.length) {
        return _fail('INVALID_EDITOR_RANGE');
      }
      if (!_perform(target, submitted, guard, A11yAction.setText, {'text': text})) {
        return _fail('EDITOR_WRITE_REJECTED');
      }
      final selected = _perform(target, submitted, guard, A11yAction.setSelection, {
        'selectionStart': start,
        'selectionEnd': end,
      });
      return _ok()..put('selectionApplied', selected);
    } on TargetChanged {
      clear();
      if (nativeAction != null) {
        return _nativeReply!.failure(
            operation == 'node', nativeAction.mayHaveSubmitted(), 'SCREEN_TARGET_CHANGED');
      }
      // 动作之前目标/运行状态就变了：动作没有落地，给调用方一个「未执行」的稳定码（#140）。
      if (submitted[0]) {
        return _fail('VIRTUAL_INPUT_RESULT_UNKNOWN')
          ..put('executionUnknown', true)
          ..put('state', 'PARTIAL');
      }
      return _fail('SCREEN_TARGET_CHANGED');
    } catch (error) {
      clear();
      if (nativeAction != null) {
        return _nativeReply!.failure(
            operation == 'node', nativeAction.mayHaveSubmitted(), 'SCREEN_TARGET_CHANGED');
      }
      final value = _fail('ACCESSIBILITY_OPERATION_UNKNOWN');
      if (submitted[0]) value.put('executionUnknown', true);
      return value;
    } finally {
      // 节点句柄由 GC/缝侧回收（原版 target/root recycle）。
    }
  }

  Map<String, Object?> _finishPerform(bool result) =>
      result ? _ok() : _fail('NODE_ACTION_REJECTED');

  bool _perform(A11yNode target, List<bool> submitted, ActionGuard guard,
      A11yAction action,
      [Map<String, Object?>? args]) {
    guard.validate();
    submitted[0] = true;
    return target.performAction(action, args);
  }

  /// 清树（原版 `clear`）。
  void clear() {
    clearObserved();
    nodes.clear();
    treeDisplay = -1;
    treeTarget = null;
  }

  void _walk(A11yNode node, List<Map<String, Object?>> tree, int depth,
      AccessibilityTreeBudget budget) {
    if (!budget.enter(depth, tree.length)) return;
    final rawText = node.isPassword() ? '' : (node.rawText() ?? '');
    final description =
        node.isPassword() ? '' : (node.contentDescription() ?? '');
    final rect = node.boundsInScreen();
    // 与主屏 dump 同一条不变量：反序矩形不是「空节点」，它的四条边都不能用来定位，
    // 报出去只会让调用方按一个错坐标点屏幕（issue #143）。
    if (AccessibilityDumpBounds.reportable(
      rawText.isNotEmpty || description.isNotEmpty,
      node.isClickable() || node.isEditable() || node.isScrollable(),
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
    )) {
      final id = vscreenUuid();
      nodes[id] = node;
      tree.add(<String, Object?>{
        'nodeId': id,
        'text': rawText.substring(0, rawText.length < 1000 ? rawText.length : 1000),
        'description': description.substring(
            0, description.length < 1000 ? description.length : 1000),
        'clickable': node.isClickable(),
        'editable': node.isEditable(),
        'scrollable': node.isScrollable(),
        'bounds': [rect.left, rect.top, rect.right, rect.bottom],
      });
    }
    for (var i = 0; i < node.childCount() && budget.childSlot(tree.length); i++) {
      // 不可读子级也消耗预算：巨大稀疏子级列表仍受限。
      final child = node.child(i);
      if (child != null) {
        _walk(child, tree, depth + 1, budget);
      }
    }
  }

  static Map<String, Object?> _ok() => <String, Object?>{'ok': true};

  static Map<String, Object?> _fail(String error) => vscreenFailure(error, false);
}

/// 动作守卫（原版嵌套 `ActionGuard`）：目标/租约在每次落地前复核。
class ActionGuard {
  ActionGuard(this.context, this.display, [this.nativeAction]);

  final VscreenContext? context;
  final int display;
  final NativeActionHandle? nativeAction;
  A11yNode? root;
  bool Function()? leaseCurrent;

  void validate() {
    final action = nativeAction;
    if (action != null) {
      action.validateRoot(display, root!);
      action.validateCurrentTarget();
      if (!action.claimDispatch() || !action.current()) throw TargetChanged();
      return;
    }
    final lease = leaseCurrent;
    if (lease != null && !lease()) throw TargetChanged();
    final ctx = context;
    if (ctx != null) {
      ctx.validateRoot(display, root!);
      if (lease != null && !lease()) throw TargetChanged();
      if (!ctx.claimDispatch()) throw TargetChanged();
      if (lease != null && !lease()) throw TargetChanged();
    }
  }
}

/// 观察属主面（原版 `VirtualScreenObservedControl`；D2 类的接线面）。
abstract class VscreenObservedControlLike {
  Map<String, Object?> run(
    int display,
    String operation,
    Map<String, Object?> args,
    VscreenContext context,
    ObservedPixelsApi pixels,
    VscreenClick click,
  );

  void invalidate();

  void clear();
}
