// lib/shared/widgets/explanation_block.dart
import 'package:flutter/material.dart';
import 'package:nursing_exam_poc/shared/theme/app_theme.dart';

/// 問題文・解説・根拠など、本文を素直に表示する共通ブロック。
/// - 余計な枠・背景は持たない（背景は Scaffold の色）
/// - 見出しは titleMedium、本文は少し大きめの bodyLarge
class ExplanationBlock extends StatelessWidget {
  const ExplanationBlock({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 見出し（問題／解説 など）
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        // 本文（やや大きめ＋行間広め）
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onSurface,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}