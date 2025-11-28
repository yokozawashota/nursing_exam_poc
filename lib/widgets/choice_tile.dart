// lib/widgets/choice_tile.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 選択肢カードの共通UI.
/// - ラベル(ABCD)は素のテキスト（丸囲いなし）
/// - normal 背景は画面（Scaffold）と同じ色に
/// - selected & correct は薄いグリーン、incorrect は薄いレッド
/// - trailing で右端にバッジ等を表示できる（結果画面用）
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.text,
    this.state = ChoiceTileState.normal,
    this.onTap,
    this.dense = false,
    this.trailing,
  });

  final String label; // 'A'..'E'
  final String text;
  final ChoiceTileState state;
  final VoidCallback? onTap;
  final bool dense;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ベース背景は Scaffold と同じ
    final Color bgScaffold = theme.scaffoldBackgroundColor;

    // テーマベースのカラー定義（AppColors を利用）
    final Color borderNormal = AppColors.textSecondary.withOpacity(0.25);
    final Color bgNormal = bgScaffold;

    final Color borderCorrect = AppColors.correct;
    final Color bgCorrect = AppColors.correct.withOpacity(0.12);

    final Color borderIncorrect = AppColors.wrong;
    final Color bgIncorrect = AppColors.wrong.withOpacity(0.12);

    Color borderColor;
    Color bgColor;
    switch (state) {
      case ChoiceTileState.normal:
        borderColor = borderNormal;
        bgColor = bgNormal;
        break;
      case ChoiceTileState.selected:
      case ChoiceTileState.correct:
        borderColor = borderCorrect;
        bgColor = bgCorrect;
        break;
      case ChoiceTileState.incorrect:
        borderColor = borderIncorrect;
        bgColor = bgIncorrect;
        break;
    }

    // 角丸は共通トークン的に 12 に統一（必要なら AppStyles に移してもOK）
    final radius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: radius,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum ChoiceTileState { normal, selected, correct, incorrect }