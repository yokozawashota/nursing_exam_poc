import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 選択肢カード（全画面統一UI）
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
    final cc = context.choiceColors;   // トークン
    final radius = BorderRadius.circular(12);

    // 色トークンに合わせて切替
    Color bg, border;
    switch (state) {
      case ChoiceTileState.normal:
        bg = cc.normalBg;
        border = cc.normalBorder;
        break;
      case ChoiceTileState.selected:
      case ChoiceTileState.correct:
        bg = cc.selectedBg;
        border = cc.selectedBorder;
        break;
      case ChoiceTileState.incorrect:
        bg = cc.incorrectBg;
        border = cc.incorrectBorder;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: radius,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ABCD ラベル（丸囲いなし）
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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