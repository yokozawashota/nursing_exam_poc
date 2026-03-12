// lib/features/mock_exam/widgets/mock_exam_header.dart
import 'package:flutter/material.dart';

class MockExamHeader extends StatelessWidget {
  const MockExamHeader({
    super.key,
    required this.modeLabel,
    required this.currentIndex,
    required this.questionCount,
    required this.hasTimeLimit,
    required this.remainingSecondsText,
    required this.progressTime,
  });

  final String modeLabel;
  final int currentIndex;
  final int questionCount;
  final bool hasTimeLimit;
  final String remainingSecondsText;
  final double progressTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                modeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Q${currentIndex + 1} / $questionCount',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            if (hasTimeLimit) ...[
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 4),
              Text(
                remainingSecondsText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (hasTimeLimit) ...[
          LinearProgressIndicator(
            value: progressTime,
            minHeight: 6,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}