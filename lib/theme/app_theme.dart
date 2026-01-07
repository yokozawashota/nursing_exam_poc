// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// NurAI 全体テーマ（カラー / 角丸 / 影 / テキスト）
/// ピンクベース（看護師イメージ）
/// ------------------------------------------------------------

class AppColors {
  // メインブランドカラー（看護師イメージのソフトピンク系）
  static const primary = Color(0xFFFF8FA8);        // メインピンク
  static const primaryDark = Color(0xFFE6778F);    // 濃いピンク
  static const primaryLight = Color(0xFFFFD6DF);   // 薄いピンク

  // サーフェス
  static const surface = Colors.white;
  static const background = Color(0xFFFFF7F9);     // ほんのりピンク背景

  // テキスト
  static const textPrimary = Color(0xFF2E2E3A);
  static const textSecondary = Color(0xFF6B6B7A);

  // ナビゲーションバー
  static const navBarBackground = Colors.white;
  static const navBarIcon = Color(0xFF8A7A82);     // ピンクに馴染むグレー

  // 正解 / 不正解（スコア・Result用）
  static const correct = Color(0xFF26C281);
  static const wrong = Color(0xFFE74C3C);
}

/// ------------------------------------------------------------
/// Typography
/// ------------------------------------------------------------
class AppText {
  static const headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

/// ------------------------------------------------------------
/// ボタンStyle
/// ------------------------------------------------------------
class AppStyles {
  static ButtonStyle ctaButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ElevatedButton.styleFrom(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      minimumSize: const Size(double.infinity, 56),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ButtonStyle outlinedButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 1.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

/// ------------------------------------------------------------
/// Main ThemeData
/// ------------------------------------------------------------
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,

    /// カラースキーム
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      background: AppColors.background,
    ),

    scaffoldBackgroundColor: AppColors.background,

    /// AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),

    /// BottomNavigationBar（下部タブ）
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navBarBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.navBarIcon,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 8,
    ),

    /// FAB（ホームの丸ボタン）
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: CircleBorder(),
    ),

    /// SnackBar
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      contentTextStyle: TextStyle(color: Colors.white),
    ),

    /// テキスト選択
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primaryLight,
    ),
  );
}