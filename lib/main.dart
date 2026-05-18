import 'package:flutter/material.dart';
import 'rust/ffi_manual.dart';
import 'core/theme/app_theme.dart';
import 'core/screens/app_launcher_screen.dart';

void main() {
  HermesFFI.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Agent',
      theme: obsidianTheme(),
      home: AppLauncherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
