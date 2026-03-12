// lib/features/past_exam/screens/past_exam_year_list_screen.dart

import 'package:flutter/material.dart';

import '../models/past_exam_history.dart';
import '../services/past_exam_repository.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/base_scaffold.dart';
import 'past_exam_list_screen.dart';
import 'past_exam_my_answers_year_list_screen.dart';
import 'past_exam_years.dart';

/// 年度別の過去問一覧（「第113回（2024年）」など）
class PastExamYearListScreen extends StatelessWidget {
  const PastExamYearListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ 年度追加はここではなく past_exam_years.dart に集約
    final years = pastExamYears;
    final examIds = years.map((e) => e.id).toList();

    return BaseScaffold(
      title: '年度別出題',
      body: ValueListenableBuilder<int>(
        valueListenable: PastExamHistory.instance.versionListenable,
        builder: (context, _, __) {
          return FutureBuilder<Map<String, int>>(
            future: PastExamHistory.instance.solvedCountMap(examIds),
            builder: (context, solvedSnap) {
              final solvedMap = solvedSnap.data ?? const <String, int>{};

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // ==== 解答履歴一覧へ ====
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('過去問の解答履歴'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PastExamMyAnswersYearListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ==== 年度カード ====
                  ...years.map((y) {
                    final solved = solvedMap[y.id] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          // ✅ 総問題数は assets から自動で算出
                          final total = await PastExamRepository.instance.totalQuestionsOfExam(y.id);

                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PastExamListScreen(
                                examId: y.id,
                                examTitle: y.title,
                                totalQuestions: total,
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
                                      '解答済：$solved問',
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

                  if (solvedSnap.connectionState == ConnectionState.waiting)
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