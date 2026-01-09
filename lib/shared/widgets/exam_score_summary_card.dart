// lib/shared/widgets/exam_score_summary_card.dart

import 'package:flutter/material.dart';
import '../models/answer_history.dart';
import '../theme/app_theme.dart';

/// 国試スコア（目安）カード
///
/// 必修：50点満点 → 必修正答率 × 50
/// 一般＋状況設定：350点満点 → 正答率 × 350
///
/// 最終スコアは合算して400点換算
class ExamScoreSummaryCard extends StatelessWidget {
  final List<AnswerRecord> records;

  const ExamScoreSummaryCard({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // -------- 分類して集計 --------
    final compulsory = records.where((r) => r.difficulty == '必修問題').toList();
    final general = records.where((r) => r.difficulty == '一般問題').toList();
    final situational =
    records.where((r) => r.difficulty == '状況設定問題').toList();

    double rate(List<AnswerRecord> list) {
      if (list.isEmpty) return 0.0;
      final c = list.where((r) => r.isCorrect).length;
      return c / list.length;
    }

    final rateComp = rate(compulsory);
    final rateGen = rate(general);
    final rateSit = rate(situational);

    // -------- 厚労省の配点ルールに基づく換算 --------
    final scoreComp = rateComp * 50; // 必修 50点満点
    final scoreGenSit = ((general.length + situational.length) == 0)
        ? 0.0
        : rate(
        [...general, ...situational]
    ) *
        350; // 一般＋状況設定 350点満点

    final scoreTotal = scoreComp + scoreGenSit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
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
          // タイトル
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

          // 合計スコア
          Text(
            '合計：${scoreTotal.toStringAsFixed(1)} / 400 点',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 詳細
          Text(
            '必修：${scoreComp.toStringAsFixed(1)} / 50 点（正答率 ${(rateComp * 100).toStringAsFixed(1)}%・${compulsory.where((r) => r.isCorrect).length}/${compulsory.length}問）',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            '一般＋状況設定：${scoreGenSit.toStringAsFixed(1)} / 350 点（正答率 ${(rate([...general, ...situational]) * 100).toStringAsFixed(1)}%・${[...general, ...situational].where((r) => r.isCorrect).length}/${general.length + situational.length}問）',
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