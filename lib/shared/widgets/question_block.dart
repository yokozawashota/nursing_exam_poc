// lib/features/practice/widgets/question_block.dart
import 'package:flutter/material.dart';

import 'app_buttons.dart';
import 'choice_tile.dart';

class QuestionBlock extends StatelessWidget {
  final String questionText;
  final Map<String, String> choices;        // {'A':'...', 'B':'...'}
  final String questionKind;                // 'single' | 'multiple' | 'select_incorrect'

  // 単一
  final String? selectedLabel;
  final ValueChanged<String>? onSelect;

  // 複数
  final List<String>? selectedLabels;
  final ValueChanged<String>? onToggle;

  // 送信
  final VoidCallback onSubmit;

  const QuestionBlock({
    super.key,
    required this.questionText,
    required this.choices,
    required this.questionKind,
    this.selectedLabel,
    this.onSelect,
    this.selectedLabels,
    this.onToggle,
    required this.onSubmit,
  });

  bool get _isMultiple =>
      questionKind == 'multiple' || questionKind == 'select_incorrect';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 問題文（全画面で統一）
        Text(
          questionText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // 選択肢
        ...choices.entries.map((e) {
          final label = e.key;
          final text  = e.value;

          final bool isSelected = _isMultiple
              ? (selectedLabels ?? const []).contains(label)
              : (selectedLabel == label);

          final state = isSelected
              ? ChoiceTileState.selected
              : ChoiceTileState.normal;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ChoiceTile(
              label: label,
              text: text,
              state: state,
              onTap: _isMultiple
                  ? (onToggle == null ? null : () => onToggle!(label))
                  : (onSelect == null ? null : () => onSelect!(label)),
            ),
          );
        }),

        const SizedBox(height: 8),

        // 解答ボタン（共通ボタンに統一）
        SizedBox(
          width: double.infinity,
          child: AppButtons.primary(
            label: '解答する',
            icon: Icons.check,
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}