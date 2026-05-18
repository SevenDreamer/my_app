import 'package:flutter/material.dart';

// ==================== Obsidian 配色 ====================
const obsidianBg = Color(0xFF1E1E1E);
const obsidianSurface = Color(0xFF2A2A2A);
const obsidianSurfaceHover = Color(0xFF323232);
const obsidianBorder = Color(0xFF3E3E3E);
const obsidianAccent = Color(0xFF7C5CFC);
const obsidianAccentAlt = Color(0xFF57A6FF);
const obsidianText = Color(0xFFDCDCDD);
const obsidianTextMuted = Color(0xFF9B9B9B);
const obsidianSuccess = Color(0xFF4EC9B0);
const obsidianWarning = Color(0xFFFFCB6B);
const obsidianError = Color(0xFFFF6B6B);

// ==================== 主题 ====================
ThemeData obsidianTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: obsidianAccent,
      secondary: obsidianAccentAlt,
      surface: obsidianSurface,
      onSurface: obsidianText,
    ),
    scaffoldBackgroundColor: obsidianBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: obsidianBg,
      foregroundColor: obsidianText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: obsidianSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: obsidianBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: obsidianAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: obsidianAccent,
        side: const BorderSide(color: obsidianBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: obsidianBg,
      selectedIconTheme: IconThemeData(color: obsidianAccent),
      unselectedIconTheme: IconThemeData(color: obsidianTextMuted),
      selectedLabelTextStyle: TextStyle(color: obsidianAccent),
      unselectedLabelTextStyle: TextStyle(color: obsidianTextMuted),
    ),
    dividerTheme: const DividerThemeData(
      color: obsidianBorder,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: obsidianText),
      bodySmall: TextStyle(color: obsidianTextMuted),
    ),
    iconTheme: const IconThemeData(color: obsidianTextMuted),
  );
}
