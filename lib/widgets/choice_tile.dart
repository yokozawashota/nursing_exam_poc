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

    // トークン適用
    final Color bgScaffold = theme.scaffoldBackgroundColor;
    final Color borderNormal = AppTheme.borderNeutral;
    final Color bgNormal     = bgScaffold;

    final Color borderCorrect = AppTheme.borderCorrect;
    final Color bgCorrect     = AppTheme.bgCorrect;

    final Color borderIncorrect = AppTheme.borderWrong;
    final Color bgIncorrect     = AppTheme.bgWrong;

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

    final radius = BorderRadius.circular(AppTheme.rMd);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
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
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge,
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