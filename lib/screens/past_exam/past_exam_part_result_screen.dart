// lib/screens/past_exam/past_exam_result_screen.dart

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/base_scaffold.dart';
import '../../models/nurai_question.dart';
import 'past_exam_question_screen.dart';

/// 過去問 1 パート分を解いたあとの結果画面
class PastExamPartResultScreen extends StatelessWidget {
  const PastExamPartResultScreen({
    super.key,
    required this.examTitle,
    required this.partLabel,
    required this.questions,
    required this.questionResults,
  });

  final String examTitle;
  final String partLabel;
  final List<NuraiQuestion> questions;
  final List<bool?> questionResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ------ 集計 ------
    final total = questions.length;
    final answeredIndices = <int>[];
    final correctIndices = <int>[];
    final wrongIndices = <int>[];

    for (var i = 0; i < questions.length; i++) {
      final r = questionResults.length > i ? questionResults[i] : null;
      if (r == null) continue;
      answeredIndices.add(i);
      if (r) {
        correctIndices.add(i);
      } else {
        wrongIndices.add(i);
      }
    }

    final unansweredIndices = List<int>.generate(total, (i) => i)
      ..removeWhere(answeredIndices.contains);

    final answeredCount = answeredIndices.length;
    final correctCount = correctIndices.length;
    final acc = answeredCount == 0 ? 0.0 : correctCount / answeredCount;

    // 分野別集計
    final Map<String, _DomainBucket> byDomain = {};
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final label = (q.domain.isEmpty) ? '未分類' : q.domain;
      final bucket =
      byDomain.putIfAbsent(label, () => _DomainBucket(domain: label));
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
                const SizedBox(height: 16),

                // 分野別成績
                Text(
                  '分野別成績',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (domainList.isEmpty)
                  Text(
                    'まだ解答済みの問題がありません。',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  )
                else
                  Column(
                    children: domainList
                        .map((b) => _domainRow(theme, b))
                        .toList(),
                  ),

                const SizedBox(height: 24),

                // 未解答・要復習セクション
                Text(
                  '復習のおすすめ',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _reviseSection(
                  context,
                  theme,
                  unansweredIndices: unansweredIndices,
                  wrongIndices: wrongIndices,
                ),
              ],
            ),
          ),
        ),
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
          Text(
            '$examTitle  $partLabel',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
            style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          Text(
            '${b.correct} / ${b.total} 問 正解',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ----- 復習セクション（未解答・誤答のみで解き直し） -----
  Widget _reviseSection(
      BuildContext context,
      ThemeData theme, {
        required List<int> unansweredIndices,
        required List<int> wrongIndices,
      }) {
    final cs = theme.colorScheme;

    final hasUnanswered = unansweredIndices.isNotEmpty;
    final hasWrong = wrongIndices.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasUnanswered && !hasWrong)
            Text(
              'このパートはすべて正解＆解き終わっています。おつかれさまでした！',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            if (hasUnanswered) ...[
              Text(
                '未解答：${unansweredIndices.length}問',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
            ],
            if (hasWrong) ...[
              Text(
                '要復習（誤答）：${wrongIndices.length}問',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],
            if (hasUnanswered)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final qs = [
                      for (final i in unansweredIndices) questions[i],
                    ];
                    if (qs.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PastExamQuestionScreen(
                          examTitle: examTitle,
                          partLabel: '$partLabel（未解答のみ）',
                          questions: qs,
                        ),
                      ),
                    );
                  },
                  child: const Text('未解答の問題だけ解き直す'),
                ),
              ),
            if (hasUnanswered && hasWrong) const SizedBox(height: 8),
            if (hasWrong)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final qs = [
                      for (final i in wrongIndices) questions[i],
                    ];
                    if (qs.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PastExamQuestionScreen(
                          examTitle: examTitle,
                          partLabel: '$partLabel（誤答の復習）',
                          questions: qs,
                        ),
                      ),
                    );
                  },
                  child: const Text('誤答になった問題を復習する'),
                ),
              ),
          ],
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