import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'rust/ffi_manual.dart';
import 'core/theme/app_theme.dart';
import 'core/screens/app_launcher_screen.dart';

void main() {
  CoreFFI.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'My App',
      theme: const ThemeData.dark(),
      materialTheme: obsidianTheme(),
      home: AppLauncherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
