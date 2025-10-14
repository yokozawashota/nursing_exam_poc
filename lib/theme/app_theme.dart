import 'package:flutter/material.dart';

/// アプリ共通テーマ（色/文字/余白/角丸）を一元管理
class AppTheme {
  AppTheme._();

  // 色トークン
  static const Color bgScaffold = Color(0xFFF7F8FA);
  static const Color borderNeutral = Color(0xFFE0E3E7);

  // 選択肢色（薄緑/薄赤）
  static const Color borderCorrect = Color(0xFFA7D7A9);
  static const Color bgCorrect     = Color(0xFFEFF9F0);
  static const Color borderWrong   = Color(0xFFF2B2B0);
  static const Color bgWrong       = Color(0xFFFDEEEE);

  // 角丸/余白
  static const double rMd = 12;
  static const EdgeInsets contentPad = EdgeInsets.fromLTRB(16, 16, 16, 24);

  // テキストスタイル
  static const String jpFont = 'NotoSansJP';

  static ThemeData light() {
    return ThemeData(
      useMaterial3: false,
      fontFamily: jpFont,
      scaffoldBackgroundColor: bgScaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgScaffold,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        // 見出し（画面タイトルや「解説」など）
        titleMedium: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, height: 1.25, color: Colors.black87),
        // 本文（問題文/選択肢/解説の本文）
        bodyLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: Colors.black87),
        bodyMedium: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: Colors.black87),
      ),
    );
  }
}