import 'package:flutter/material.dart';

/// 選択肢カード用の共通テーマ（色・角丸・余白）
class ChoiceTheme {
  // ベース色
  static const bgSurface = Color(0xFFF7F3F8); // 画面全体の淡い背景（必要なら）
  static const bgCard    = Colors.white;

  // 枠線カラー（薄め）
  static const border    = Color(0xFFE0E0E6);

  // 選択時（問題画面）
  static const selBg     = Color(0xFFEAF7EF); // 薄い緑
  static const selBorder = Color(0xFFB7E0C2);

  // 結果：正解
  static const okBg      = Color(0xFFEAF7EF); // 薄い緑（統一）
  static const okBorder  = Color(0xFFB7E0C2);

  // 結果：不正解
  static const ngBg      = Color(0xFFFDECEC); // 薄い赤
  static const ngBorder  = Color(0xFFF2B8B5); // 薄い赤枠（強すぎない）

  // 結果：参考（他の選択肢で正解でも不正解でもない＝ニュートラル）
  static const neutralBg     = Colors.white;
  static const neutralBorder = border;

  // 角丸・影・余白
  static const radius = 16.0;
  static const cardPadding = EdgeInsets.fromLTRB(16, 18, 16, 18);

  static BoxDecoration box({
    required Color bg,
    required Color br,
  }) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: br, width: 1),
    );
  }
}

/// 問題文の共通スタイル
class QuestionText extends StatelessWidget {
  final String text;
  const QuestionText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        height: 1.6,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}