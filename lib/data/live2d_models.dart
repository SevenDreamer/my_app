//! Live2D 模型清单（数据层）——UI 与数据分离
//!
//! 模型目录/文件名的映射关系只在这里维护；页面只消费。
//! 模型资产默认**不随包分发**（贴图占安装包一半以上），
//! 从 R2 按需下载（见 services/model_downloader.dart）；
//! 本地已有文件时优先加载本地。

/// 单个模型的定义（内置资产路径 + 按需下载元数据）
class ModelDef {
  const ModelDef(
    this.label,
    this.dir,
    this.file, {
    this.description = '',
    this.zipUrl,
    this.zipSize,
    this.sha256,
    this.entry,
  });

  final String label;

  /// 资产目录（server 路由前缀 assets/ 之下）
  final String dir;

  /// model3.json 文件名
  final String file;

  /// 设备端说明（可选——设置页展示用）
  final String description;

  /// 模型 zip 的下载地址（R2）；null = 不支持下载
  final String? zipUrl;

  /// zip 字节数（进度/展示用）
  final int? zipSize;

  /// zip 的 SHA256（下载校验）
  final String? sha256;

  /// 解压后的相对入口（默认 = file）
  final String? entry;

  /// 模型唯一 id（下载目录名）
  String get id {
    // dir 形如 'assets/models/mao/' → id = 'mao'
    final parts = dir.split('/')..removeWhere((s) => s.isEmpty);
    return parts.last;
  }

  /// 模型入口文件的资产路径（内置资产场景用）
  String get assetPath => '$dir$file';
}

const live2dModels = <ModelDef>[
  ModelDef('Mao', 'assets/models/mao/', 'mao_pro.model3.json',
      description: '8 种表情 · 7 组动作',
      zipUrl:
          'https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist/models/mao.zip',
      zipSize: 8407454,
      sha256:
          'c8986cb92c84ce9d438409c2d0bdc4f311c2f93d82831550b3ad9d4cf7474a44'),
  ModelDef('Ren', 'assets/models/ren/', 'ren.model3.json',
      description: '5 种表情 · 3 组动作',
      zipUrl:
          'https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist/models/ren.zip',
      zipSize: 4490613,
      sha256:
          'bca412976492ee42fbdaa46aba936335043acc4abae7d00d8f4aafae424d7db8'),
  ModelDef('IceGirl', 'assets/models/icegirl/', 'IceGirl.model3.json',
      description: '待机/挥手动作 · 8K 贴图',
      zipUrl:
          'https://pub-887a8744be9247ceba718deacb4e03eb.r2.dev/my_app_dist/models/icegirl.zip',
      zipSize: 17583213,
      sha256:
          '641d9f200821ba767be508860b774a42515966a4551a8bbc96a3d16aa79bc531'),
];
