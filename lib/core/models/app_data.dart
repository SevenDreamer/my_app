import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/core/router/app_router.dart';

/// 内置子应用列表（MVP方案：所有子应用内置在主应用中）
const builtInApps = <SubApp>[
  SubApp(
    id: 'image',
    name: '图片处理',
    description: 'AI 图片生成与编辑',
    iconName: 'image',
    color: Color(0xFF57A6FF),
    route: AppRoutes.image,
  ),
  // TODO: 修复 hermes_api Rust 编译错误后恢复
  // SubApp(
  //   id: 'hermes',
  //   name: 'Hermes',
  //   description: 'AI 助手对话',
  //   iconName: 'message_circle',
  //   color: Color(0xFF7C5CFC),
  //   route: AppRoutes.hermes,
  // ),
  SubApp(
    id: 'bar',
    name: '酒吧管理',
    description: '酒吧库存与销售管理',
    iconName: 'wine',
    color: Color(0xFFE8AA42),
    route: AppRoutes.bar,
  ),
  SubApp(
    id: 'database',
    name: '数据库管理',
    description: '管理数据库连接',
    iconName: 'database',
    color: Color(0xFFFF6B6B),
    route: AppRoutes.database,
  ),
];
