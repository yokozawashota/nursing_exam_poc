// lib/features/past_exam/screens/past_exam_result_screen.dart

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/base_scaffold.dart';
import '../models/past_exam_question.dart';
import '../models/past_exam_history.dart';

/// 過去問 1 パート分を解いたあとの結果画面
/// ✅ この画面には「未解答/誤答を解き直す」ボタンを置かない（整理のため撤去）
class PastExamPartResultScreen extends StatelessWidget {
  const PastExamPartResultScreen({
    super.key,
    required this.examId, // ✅ 推測排除
    required this.examTitle,
    required this.partLabel,
    required this.questions,
    required this.questionResults,
    this.partKind,
  });

  /// ✅ 年度別リセットで必須
  final String examId;

  final String examTitle;
  final String partLabel;
  final List<NuraiQuestion> questions;
  final List<bool?> questionResults;

  /// 任意（将来用：今はこの画面では未使用）
  final String? partKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ------ 集計 ------
    final total = questions.length;

    var answeredCount = 0;
    var correctCount = 0;

    for (var i = 0; i < questions.length; i++) {
      final r = questionResults.length > i ? questionResults[i] : null;
      if (r == null) continue;
      answeredCount++;
      if (r == true) correctCount++;
    }

    final acc = answeredCount == 0 ? 0.0 : correctCount / answeredCount;

    // 分野別集計
    final Map<String, _DomainBucket> byDomain = {};
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final label = (q.domain.isEmpty) ? '未分類' : q.domain;

      final bucket = byDomain.putIfAbsent(label, () => _DomainBucket(domain: label));
      bucket.total++;

      final r = questionResults.length > i ? questionResults[i] : null;
      if (r == true) bucket.correct++;
    }

    final domainList = byDomain.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return BaseScaffold(
      title: '過去問の結果',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 概要カード
                _summaryCard(
                  theme,
                  total: total,
                  answered: answeredCount,
                  correct: correctCount,
                  accuracy: acc,
                ),

                const SizedBox(height: 12),

                // ✅ 年度別リセット（推測せず examId をそのまま使う）
                _resetYearButton(context, theme),

                const SizedBox(height: 16),

                // 分野別成績
                Text(
                  '分野別成績',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (domainList.isEmpty)
                  Text(
                    'まだ解答済みの問題がありません。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  )
                else
                  Column(
                    children: domainList.map((b) => _domainRow(theme, b)).toList(),
                  ),

                const SizedBox(height: 16),

                // ✅ この画面は「結果」なので、最後に戻るだけ
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('戻る'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resetYearButton(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withOpacity(0.8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('この年度の過去問履歴をリセット'),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('年度別リセット'),
              content: Text(
                '$examTitle の過去問解答履歴をすべて削除します。\n'
                    '（必修AM/PM、一般AM/PM すべて対象）\n\n'
                    'この操作は取り消せません。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.error),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('削除する'),
                ),
              ],
            ),
          );

          if (ok != true) return;

          await PastExamHistory.instance.resetExam(examId);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('年度の過去問履歴をリセットしました')),
          );

          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ----- 上部の概要カード -----
  Widget _summaryCard(
      ThemeData theme, {
        required int total,
        required int answered,
        required int correct,
        required double accuracy,
      }) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$examTitle  $partLabel',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('総問題数：$total 問'),
          Text('解答済：$answered 問'),
          Text('正解数：$correct 問'),
          Text('正答率：${(accuracy * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  // ----- 分野別の1行＋バー -----
  Widget _domainRow(ThemeData theme, _DomainBucket b) {
    final cs = theme.colorScheme;
    final rate = b.total == 0 ? 0.0 : b.correct / b.total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.domain,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: rate.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(rate * 100).toStringAsFixed(1)}%', style: theme.textTheme.bodySmall),
            ],
          ),
          Text(
            '${b.correct} / ${b.total} 問 正解',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DomainBucket {
  final String domain;
  int total = 0;
  int correct = 0;

  _DomainBucket({required this.domain});
}