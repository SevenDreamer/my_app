//! 表情语义定义：只声明"有哪些表情、叫什么"，不涉及任何长相
//!
//! 每种眼睛样式（EyeRenderer 实现）自行定义这些表情的具体画法，
//! 因此这里只保留语义枚举——右键菜单、键盘快捷键、状态管理都只认它。
enum ExpressionType {
  neutral('平静'),
  happy('开心'),
  surprised('惊讶'),
  angry('生气'),
  sleepy('困'),
  love('爱心'),
  dead('死机'),
  smug('得意');

  const ExpressionType(this.label);

  /// 右键菜单里显示的名字
  final String label;
}
