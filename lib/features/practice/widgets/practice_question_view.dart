// lib/features/practice/widgets/practice_question_view.dart

import 'package:flutter/material.dart';

import '../../../shared/widgets/question_block.dart';

class PracticeQuestionView extends StatelessWidget {
  const PracticeQuestionView({
    super.key,
    required this.questionText,
    required this.choices,
    required this.questionKind,
    required this.selectedAnswers,
    required this.onSelectSingle,
    required this.onToggleMultiple,
    required this.onSubmit,
  });

  final String questionText;
  final Map<String, String> choices;
  final String questionKind;
  final List<String> selectedAnswers;

  final ValueChanged<String> onSelectSingle;
  final ValueChanged<String> onToggleMultiple;
  final VoidCallback onSubmit;

  bool get _isMulti =>
      questionKind == 'multiple' ||
          questionKind == 'select_incorrect' ||
          selectedAnswers.length >= 2;

  @override
  Widget build(BuildContext context) {
    return QuestionBlock(
      questionText: questionText,
      choices: choices,
      questionKind: questionKind,
      selectedLabel:
      !_isMulti && selectedAnswers.isNotEmpty ? selectedAnswers.first : null,
      onSelect: !_isMulti ? onSelectSingle : null,
      selectedLabels: _isMulti ? selectedAnswers : null,
      onToggle: _isMulti ? onToggleMultiple : null,
      onSubmit: onSubmit,
    );
  }
}