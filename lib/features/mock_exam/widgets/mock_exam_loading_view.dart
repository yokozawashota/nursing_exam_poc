// lib/features/mock_exam/widgets/mock_exam_loading_view.dart
import 'package:flutter/material.dart';

class MockExamLoadingView extends StatelessWidget {
  const MockExamLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: 10),
          Text(
            '次の問題を読み込み中…',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}