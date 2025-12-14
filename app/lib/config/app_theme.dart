import 'package:flutter/material.dart';

/// アプリケーション全体のカラーパレット。
///
/// Flutter Cyan をベースとしたモダンなデザインを提供する。
class AppColors {
  // プライマリカラー（Flutter Cyan）
  static const primary = Color(0xFF00BCD4); // Cyan 500
  static const primaryLight = Color(0xFF4DD0E1); // Cyan 300
  static const primaryDark = Color(0xFF0097A7); // Cyan 700

  // サーフェス
  static const surfaceLight = Color(0xFFFAFAFA); // Light background
  static const surfaceDark = Color(0xFF121212); // Dark background
  static const sidebarLight = Color(0xFFF5F5F5);
  static const sidebarDark = Color(0xFF1E1E1E);

  // アクセント
  static const accent = Color(0xFF00ACC1); // Cyan 600
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const error = Color(0xFFE57373);

  // テキスト
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textOnPrimary = Colors.white;
}

/// アプリケーションのテーマ設定。
class AppTheme {
  /// ライトテーマ
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.surfaceLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    dividerColor: Colors.grey.shade300,
  );

  /// ダークテーマ
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.surfaceDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sidebarDark,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    dividerColor: Colors.grey.shade800,
  );
}
