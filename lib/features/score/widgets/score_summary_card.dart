// lib/features/score/widgets/score_summary_card.dart

import 'package:flutter/material.dart';

import '../../history/services/history_answer_service.dart';
import '../services/score_exam_service.dart';
import '../../../shared/theme/app_theme.dart';

/// 国試スコア（目安）カード
///
/// 必修：50点満点 → 必修正答率 × 50
/// 一般＋状況設定：350点満点 → 正答率 × 350
///
/// 最終スコアは合算して 400 点換算で表示する。
///
/// 集計ロジックは ExamScoreService に委譲し、
/// このWidgetは表示に専念する。
class ScoreSummaryCard extends StatelessWidget {
  final List<AnswerRecord> records;

  const ScoreSummaryCard({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examScore = ExamScoreService.calculate(records);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: AppColors.primary, size: 28),
              const SizedBox(width: 8),
              Text(
                '国試スコア（目安）',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            '合計：${examScore.totalScore.toStringAsFixed(1)} / 400 点',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            '必修：${examScore.hisshuScore.toStringAsFixed(1)} / 50 点（正答率 ${(examScore.hisshuRate * 100).toStringAsFixed(1)}%・${examScore.correctHisshu}/${examScore.answeredHisshu}問）',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            '一般＋状況設定：${examScore.generalScore.toStringAsFixed(1)} / 350 点（正答率 ${(examScore.generalRate * 100).toStringAsFixed(1)}%・${examScore.correctGeneralLike}/${examScore.answeredGeneralLike}問）',
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 12),
          Text(
            '※厚生労働省の正式な採点表を再現したものではなく、正答率から換算した目安スコアです。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}