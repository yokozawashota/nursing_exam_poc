// lib/screens/past_exam/past_exam_my_answers_year_list_screen.dart
import 'package:flutter/material.dart';

import '../../models/past_exam_history.dart';
import '../../theme/app_theme.dart';
import '../../widgets/base_scaffold.dart';
import 'past_exam_my_answers_list_screen.dart';

class PastExamMyAnswersYearListScreen extends StatelessWidget {
  const PastExamMyAnswersYearListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 年度メタ（必要なら増やしてOK）
    final years = <_PastExamYearMeta>[
      const _PastExamYearMeta(id: '111', title: '第111回（2022年）', totalQuestions: 240),
      const _PastExamYearMeta(id: '113', title: '第113回（2024年）', totalQuestions: 240),
    ];

    final examIds = years.map((e) => e.id).toList();

    return BaseScaffold(
      title: '自分の解答（年度別）',
      body: ValueListenableBuilder<int>(
        valueListenable: PastExamHistory.instance.versionListenable,
        builder: (context, _, __) {
          return FutureBuilder<Map<String, int>>(
            future: PastExamHistory.instance.solvedCountMap(examIds),
            builder: (context, snap) {
              final solvedMap = snap.data ?? const <String, int>{};

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      '各年度を選ぶと、その年度で解答した問題を一覧で確認できます。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...years.map((y) {
                    final solved = solvedMap[y.id] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PastExamMyAnswersListScreen(
                                examId: y.id,
                                examTitle: y.title,
                                totalQuestions: y.totalQuestions,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      y.title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '解答済：$solved問／${y.totalQuestions}問',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  if (snap.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PastExamYearMeta {
  final String id;
  final String title;
  final int totalQuestions;

  const _PastExamYearMeta({
    required this.id,
    required this.title,
    required this.totalQuestions,
  });
}