// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenActivity（NodePanel 判定段）—— 现代化重构，行为契约不变。
//! 节点面板判定：只显示后端核验过的目标（packageInput 只是启动草稿）。
//! 「Consume the rendered list before queuing. Neither double-clicks nor late callbacks replay it.」
//! 「A user opens this separate owner explicitly; failed coordinate input never calls it.」
library;

import 'support.dart';
import 'ui_outcome.dart';

/// 节点目标可核验（原版 refreshNodes 核验段）。
bool nodeTargetVerifiable(Map<String, Object?> out) =>
    out.optString('packageName').trim().isNotEmpty &&
    out.optString('coreInstance').trim().isNotEmpty &&
    out.optString('generation').trim().isNotEmpty &&
    out.optInt('displayId', -1) > 0 &&
    out.optInt('windowId', -1) >= 0;

/// 可编辑节点（原版 `editableNode`）。
bool editableNode(Map<String, Object?> node) =>
    node.optBoolean('editable') &&
    node.optBoolean('setTextSupported') &&
    !node.optBoolean('password');

/// 节点行可列（原版列表过滤）。
bool nodeRowListable(Map<String, Object?> node) =>
    node.optBoolean('enabled') &&
    node.optString('nodeId').trim().isNotEmpty &&
    (node.optBoolean('clickable') || editableNode(node));

/// 节点标签（原版 `nodeLabel`）。
String nodeLabel(Map<String, Object?> node, {UiTextChoose choose = _zh}) {
  final text = node.optString('text').trim();
  final description = node.optString('description').trim();
  if (text.isEmpty) {
    return description.isEmpty ? choose('未标注控件', 'Unlabelled control') : description;
  }
  return description.isEmpty || description == text ? text : '$text · $description';
}

String _zh(String zh, String en) => zh;

/// 结果未知判定（原版 `unknownNodeResult`）。
bool unknownNodeResult(Map<String, Object?>? out) =>
    out == null ||
    out.optBoolean('executionUnknown') ||
    out.optString('error').contains('UNKNOWN');

/// 节点失败决策（原版 `nodeFailure`）：哪些失败撤销本次节点会话。
class NodeFailureDecision {
  const NodeFailureDecision({required this.revoke, required this.message});

  /// true = `panel.revoked = true` + `controls.close()`（本会话终止，需重开面板）。
  final bool revoke;
  final String message;
}

/// 节点失败分类（原版 `nodeFailure` 判定表）。
NodeFailureDecision nodeFailureDecision(Map<String, Object?>? out,
    {UiTextChoose choose = _zh}) {
  if (unknownNodeResult(out)) {
    return NodeFailureDecision(
        revoke: true,
        message: choose(
            '结果未知，请查看实际画面；需要继续时重新打开节点操作。不会自动重试。',
            'Result unknown. Check the actual picture; open Node actions again if needed. No automatic retry.'));
  }
  final error = out!.optString('error');
  if (error == 'ACCESSIBILITY_UNAVAILABLE') {
    return NodeFailureDecision(
        revoke: true,
        message: choose(
            'DSHA 无障碍当前不可用；请检查授权和虚拟屏，恢复后关闭并重新打开节点操作。',
            'DSHA accessibility is unavailable. Check access and the virtual screen, then close and reopen Node actions after restoring access.'));
  }
  if (error == 'VIRTUAL_WINDOW_UNAVAILABLE') {
    return NodeFailureDecision(
        revoke: true,
        message: choose(
            '系统未提供当前虚拟屏窗口；请检查应用画面后关闭并重新打开节点操作。',
            'The system did not provide the virtual window. Check the app picture, then close and reopen Node actions.'));
  }
  if (error == 'NATIVE_CONTROL_REVOKED' || error == 'SCREEN_TARGET_CHANGED') {
    return NodeFailureDecision(
        revoke: true,
        message: choose(
            '节点操作许可已失效；请检查实际画面，需要继续时重新打开节点操作。',
            'This node session expired. Check the actual picture, then open Node actions again if needed.'));
  }
  if (error == 'STALE_TREE' || error == 'STALE_NODE') {
    return NodeFailureDecision(
        revoke: false,
        message: choose(
            '节点列表或所选控件已变化；请核对实际画面，需要继续时手动刷新节点。不会自动重发。',
            'The node list or selected control changed. Check the actual picture and refresh nodes yourself if needed. No automatic resend.'));
  }
  if (error == 'NATIVE_NODE_ACTION_UNAVAILABLE' || error == 'NODE_ACTION_REJECTED') {
    return NodeFailureDecision(
        revoke: false,
        message: choose(
            '此控件不支持或拒绝了当前操作。请检查实际画面，不会自动改用其他方式。',
            'This control does not support or refused this action. Check the actual picture. No automatic fallback.'));
  }
  return NodeFailureDecision(revoke: false, message: outcomeText(out, choose: choose));
}

/// 失败尾注（原版 error/reason/detail 追加）。
String nodeFailureText(Map<String, Object?>? out, NodeFailureDecision decision) {
  var message = decision.message;
  if (out != null && out.optString('error').trim().isNotEmpty) {
    message += '\n${out.optString('error')}';
    if (out.optString('reason').trim().isNotEmpty) {
      message += ' · ${out.optString('reason')}';
    }
    if (out.optString('detail').trim().isNotEmpty) {
      message += ' · ${out.optString('detail')}';
    }
  }
  return message;
}

/// 提交即消费渲染列表（原版 submitNode 首段）：双击与迟到回调都不得重放。
bool submitConsumes(int panelRevision, int queuedRevision) =>
    queuedRevision == panelRevision;
