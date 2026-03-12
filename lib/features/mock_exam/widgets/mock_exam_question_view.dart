// lib/features/mock_exam/widgets/mock_exam_question_view.dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/question_block.dart';

class MockExamQuestionView extends StatelessWidget {
  const MockExamQuestionView({
    super.key,
    required this.questionText,
    required this.choices,
    required this.questionKind,
    required this.isMulti,
    required this.userAnswers,
    required this.onSelectSingle,
    required this.onToggleMultiple,
    required this.onSubmit,
  });

  final String? questionText;
  final Map<String, String>? choices;
  final String questionKind;
  final bool isMulti;
  final Set<String> userAnswers;
  final ValueChanged<String> onSelectSingle;
  final ValueChanged<String> onToggleMultiple;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (questionText == null || choices == null) {
      return Center(
        child: Text(
          '問題を読み込めませんでした。',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return SingleChildScrollView(
      child: QuestionBlock(
        questionText: questionText!,
        choices: choices!,
        questionKind: questionKind,
        selectedLabel:
        !isMulti && userAnswers.isNotEmpty ? userAnswers.first : null,
        onSelect: !isMulti ? onSelectSingle : null,
        selectedLabels: isMulti ? userAnswers.toList() : null,
        onToggle: isMulti ? onToggleMultiple : null,
        onSubmit: onSubmit,
      ),
    );
  }
}