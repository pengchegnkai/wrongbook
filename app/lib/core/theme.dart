/// core/theme.dart —— 浅色/深色主题
import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  const seed = Color(0xFF3B82F6);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: CardTheme(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}

ThemeData buildDarkTheme() {
  const seed = Color(0xFF3B82F6);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: CardTheme(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
