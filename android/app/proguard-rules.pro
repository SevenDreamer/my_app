# my_app release 混淆规则（R8）

# flutter_p2p_connection：lifecycle 接口被 R8 混淆后插件注册崩溃
# （ClassCastException: HiddenLifecycleReference cannot be cast to <混淆名>，
# release 包设备互联功能全瘫、debug 包测不出）。keep 整个插件包最稳。
-keep class com.ugo.studio.plugins.flutter_p2p_connection.** { *; }
# 插件 onAttachedToActivity 对 androidx Lifecycle 接口显式强转，
# 目标接口被混淆即炸——lifecycle 库 + Flutter embedding lifecycle 一并 keep
-keep class androidx.lifecycle.** { *; }
-keep class io.flutter.embedding.engine.plugins.lifecycle.** { *; }
