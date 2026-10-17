/// core/theme.dart —— 浅色/深色主题（现代设计系统）
/// 设计语言：Material 3 + 大圆角 + 无阴影分层（用表面色阶代替 elevation）+
/// 填充式输入框 + 浮动 SnackBar。所有组件样式在主题层统一，页面不写死样式。
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 品牌色：靛蓝（比默认蓝更沉稳，深浅色模式下对比度均达标）
const _seedLight = Color(0xFF4F6BED);
const _seedDark = Color(0xFF8FA3F5);

ThemeData _baseTheme(Color seed, Brightness brightness, {ColorScheme? overrideScheme}) {
  final scheme = overrideScheme ?? ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final isLight = brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 全局去除 splash 涟漪过重感：轻微高亮即可
    splashFactory: InkSparkle.splashFactory,
    // ---- 文字 ----
    // 中文界面不加载自定义字体（保持系统字体最优渲染），
    // 用字重/字号分级 + 收紧字距实现现代排版层级
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(height: 1.5),
      bodyMedium: TextStyle(height: 1.5),
    ),
    // ---- 应用栏：融入背景、左对齐标题（现代 App 习惯）、滚动时用表面色阶分隔 ----
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
    ),
    // ---- 卡片：零阴影 + 描边 + 16 圆角（现代扁平卡片） ----
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: EdgeInsets.zero,
    ),
    // ---- 按钮：胶囊形、加大高度与内边距 ----
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    // ---- 输入框：填充式（现代表单标配），聚焦描边 2px ----
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? scheme.surfaceContainerHighest.withValues(alpha: 0.45) : scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    // ---- SnackBar：浮动 + 圆角 + 反色 ----
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isLight ? scheme.inverseSurface : scheme.inverseSurface,
    ),
    // ---- 对话框：24 圆角 ----
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    // ---- 列表项：圆角按压态（配合页面 padding 使用） ----
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    // ---- Chip：圆角胶囊 ----
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    // ---- 页面切换：Android 用 M3 缩放转场，iOS 用 Cupertino 滑动转场 ----
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildLightTheme() => _baseTheme(_seedLight, Brightness.light);

ThemeData buildDarkTheme() => _baseTheme(_seedDark, Brightness.dark);

/// Material You 动态取色入口（Android 12+ 壁纸取色；低版本返回 null 走静态主题）。
/// 动态 scheme 保住品牌级排版/组件形状，只换色板。
ThemeData? buildThemeFromScheme(ColorScheme? scheme, Brightness fallbackBrightness) {
  if (scheme == null) {
    return fallbackBrightness == Brightness.light ? buildLightTheme() : buildDarkTheme();
  }
  return _baseTheme(scheme, scheme.brightness, overrideScheme: scheme);
}
