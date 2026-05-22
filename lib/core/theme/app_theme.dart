import 'package:shadcn_flutter/shadcn_flutter.dart';

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

// ==================== ShadThemeData 构建 ====================

/// 构建 Obsidian 深色主题
ShadThemeData buildObsidianDarkTheme() {
  final colorScheme = ShadColorScheme.fromColors(
    brightness: Brightness.dark,
    primary: obsidianAccent,
    primaryForeground: Colors.white,
    secondary: obsidianAccentAlt,
    secondaryForeground: Colors.white,
    background: obsidianBg,
    foreground: obsidianText,
    card: obsidianSurface,
    cardForeground: obsidianText,
    border: obsidianBorder,
    muted: obsidianSurfaceHover,
    mutedForeground: obsidianTextMuted,
  );

  return ShadThemeData(
    colorScheme: colorScheme,
    radius: 0.7,
  );
}

/// 构建 Obsidian 浅色主题
ShadThemeData buildObsidianLightTheme() {
  const lightBg = Color(0xFFF8F8F8);
  const lightSurface = Color(0xFFFFFFFF);
  const lightBorder = Color(0xFFE5E5E5);
  const lightText = Color(0xFF1E1E1E);
  const lightTextMuted = Color(0xFF9B9B9B);

  final colorScheme = ShadColorScheme.fromColors(
    brightness: Brightness.light,
    primary: obsidianAccent,
    primaryForeground: Colors.white,
    secondary: obsidianAccentAlt,
    secondaryForeground: Colors.white,
    background: lightBg,
    foreground: lightText,
    card: lightSurface,
    cardForeground: lightText,
    border: lightBorder,
    muted: const Color(0xFFF0F0F0),
    mutedForeground: lightTextMuted,
  );

  return ShadThemeData(
    colorScheme: colorScheme,
    radius: 0.7,
  );
}
