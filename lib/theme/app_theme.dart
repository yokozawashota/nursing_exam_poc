import 'package:flutter/material.dart';

/// ------------------------------
/// デザイン・トークン（ThemeExtension）
/// ------------------------------
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  final Color page;   // 画面の背景
  final Color pill;   // 薄いカード背景（問題文・解説など）
  final Color border; // 標準ボーダー

  const AppSurfaces({
    required this.page,
    required this.pill,
    required this.border,
  });

  @override
  AppSurfaces copyWith({Color? page, Color? pill, Color? border}) {
    return AppSurfaces(
      page: page ?? this.page,
      pill: pill ?? this.pill,
      border: border ?? this.border,
    );
  }

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) return this;
    return AppSurfaces(
      page: Color.lerp(page, other.page, t)!,
      pill: Color.lerp(pill, other.pill, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

@immutable
class AppChoiceColors extends ThemeExtension<AppChoiceColors> {
  final Color normalBg;
  final Color normalBorder;
  final Color selectedBg;
  final Color selectedBorder;
  final Color incorrectBg;
  final Color incorrectBorder;

  const AppChoiceColors({
    required this.normalBg,
    required this.normalBorder,
    required this.selectedBg,
    required this.selectedBorder,
    required this.incorrectBg,
    required this.incorrectBorder,
  });

  @override
  AppChoiceColors copyWith({
    Color? normalBg,
    Color? normalBorder,
    Color? selectedBg,
    Color? selectedBorder,
    Color? incorrectBg,
    Color? incorrectBorder,
  }) {
    return AppChoiceColors(
      normalBg: normalBg ?? this.normalBg,
      normalBorder: normalBorder ?? this.normalBorder,
      selectedBg: selectedBg ?? this.selectedBg,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      incorrectBg: incorrectBg ?? this.incorrectBg,
      incorrectBorder: incorrectBorder ?? this.incorrectBorder,
    );
  }

  @override
  AppChoiceColors lerp(ThemeExtension<AppChoiceColors>? other, double t) {
    if (other is! AppChoiceColors) return this;
    return AppChoiceColors(
      normalBg: Color.lerp(normalBg, other.normalBg, t)!,
      normalBorder: Color.lerp(normalBorder, other.normalBorder, t)!,
      selectedBg: Color.lerp(selectedBg, other.selectedBg, t)!,
      selectedBorder: Color.lerp(selectedBorder, other.selectedBorder, t)!,
      incorrectBg: Color.lerp(incorrectBg, other.incorrectBg, t)!,
      incorrectBorder: Color.lerp(incorrectBorder, other.incorrectBorder, t)!,
    );
  }
}

/// アプリ共通テーマ（Light）
class AppTheme {
  static ThemeData light() {
    const seed = Color(0xFF5B6ACF); // 既存のPrimaryに近い種色

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF6EFF8), // 今の画面全体の薄い色に合わせる
      useMaterial3: true,

      // 文字スタイル（全画面で統一）
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium:  TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyLarge:    TextStyle(fontSize: 16, height: 1.5),
        bodyMedium:   TextStyle(fontSize: 15, height: 1.5),
        labelLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),

      // AppButtons.* の色は ColorScheme から取られる想定
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      // 追加トークン
      extensions: <ThemeExtension<dynamic>>[
        const AppSurfaces(
          page: Color(0xFFF6EFF8),
          pill: Color(0xFFF3F4F6),     // 問題文・解説の“とても薄い”背景
          border: Color(0xFFE0E0E0),
        ),
        AppChoiceColors(
          normalBg: const Color(0xFFF6EFF8),          // 画面背景と同色
          normalBorder: const Color(0xFFE0E0E0),
          selectedBg: Colors.green.shade50,            // 統一：薄緑
          selectedBorder: Colors.green.shade200,
          incorrectBg: Colors.red.shade50,            // 統一：薄赤
          incorrectBorder: Colors.red.shade200,
        ),
      ],
    );
  }
}

/// 取り出しを楽にする拡張
extension AppThemeX on BuildContext {
  AppSurfaces get surfaces =>
      Theme.of(this).extension<AppSurfaces>()!;
  AppChoiceColors get choiceColors =>
      Theme.of(this).extension<AppChoiceColors>()!;
}