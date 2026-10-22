//! Live2D 模型清单（数据层）——UI 与数据分离
///
/// 模型目录/文件名的映射关系只在这里维护；页面只消费。
/// 模型资产在 assets/models/（pubspec 声明），新增模型两处同步。
class ModelDef {
  const ModelDef(this.label, this.dir, this.file, {this.description = ''});

  final String label;

  /// 资产目录（server 路由前缀 assets/ 之下）
  final String dir;

  /// model3.json 文件名
  final String file;

  /// 设备端说明（可选——设置页展示用）
  final String description;

  /// 模型入口文件的资产路径（dir + file）
  String get assetPath => '$dir$file';
}

const live2dModels = <ModelDef>[
  ModelDef('Mao', 'assets/models/mao/', 'mao_pro.model3.json',
      description: '8 种表情 · 7 组动作'),
  ModelDef('Ren', 'assets/models/ren/', 'ren.model3.json',
      description: '5 种表情 · 3 组动作'),
  ModelDef('IceGirl', 'assets/models/icegirl/', 'IceGirl.model3.json',
      description: '待机/挥手动作 · 8K 贴图'),
];
