// lib/widgets/explanation_block.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 問題文・解説・根拠など、本文を素直に表示する共通ブロック。
/// - 余計な枠・背景は持たない（背景はScaffold色）
/// - 見出しは titleMedium、本文は bodyLarge
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

    // AppTheme.contentPad の代わりに統一パディングを使用
    const EdgeInsets contentPadding = EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 12,
    );

    return Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}