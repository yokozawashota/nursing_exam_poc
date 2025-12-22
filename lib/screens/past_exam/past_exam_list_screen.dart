// lib/screens/past_exam/past_exam_list_screen.dart
import 'package:flutter/material.dart';

import '../../widgets/base_scaffold.dart';
import '../../theme/app_theme.dart';
import '../../services/past_exam_repository.dart';
import '../../models/nurai_question.dart';
import 'past_exam_question_screen.dart';

/// 年度内の「パート一覧」画面（必修 午前 / 一般 午前 ...）
///
/// - assets/past_exam/<examId>/<partKey>.json を PastExamRepository で読む
class PastExamListScreen extends StatelessWidget {
  const PastExamListScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.totalQuestions, // ★ year list / home から渡す
  });

  final String examId;          // 例: '111' / '113'
  final String examTitle;       // 例: '第111回（2022年）'
  final int totalQuestions;     // 年度の総問題数（表示用）

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final parts = _buildPartsForExam(examId);

    return BaseScaffold(
      title: examTitle,
      body: ListView(
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
              '総問題数：$totalQuestions問',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          ...parts.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: p.enabled
                    ? () async {
                  try {
                    final questions = await PastExamRepository.instance.load(
                      examId: examId,
                      partKey: p.partKey,
                    );

                    if (questions.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('まだ問題が登録されていません')),
                      );
                      return;
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PastExamQuestionScreen(
                          examTitle: '$examTitle ${p.label}',
                          partLabel: p.label,
                          questions: questions,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('過去問の読み込みに失敗しました: $e')),
                    );
                  }
                }
                    : null,
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
                              p.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.enabled
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.description,
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
          }),
        ],
      ),
    );
  }

  List<_PastExamPartMeta> _buildPartsForExam(String examId) {
    // ✅ 111: 必修午前 / 一般午前 を読める
    if (examId == '111') {
      return const [
        _PastExamPartMeta(
          label: '必修問題 午前',
          description: '必修 午前の問題を解く',
          partKey: 'hisshu_am',
          enabled: true,
        ),
        _PastExamPartMeta(
          label: '一般問題 午前',
          description: '一般 午前の問題を解く',
          partKey: 'ippan_am',
          enabled: true,
        ),
      ];
    }

    // ✅ 113: テスト用（必修午前のみ）
    if (examId == '113') {
      return const [
        _PastExamPartMeta(
          label: '必修問題 午前',
          description: '必修 午前の問題を解く',
          partKey: 'hisshu_am',
          enabled: true,
        ),
      ];
    }

    return const [];
  }
}

class _PastExamPartMeta {
  final String label;
  final String description;
  final String partKey; // ★ assets/past_exam/<examId>/<partKey>.json
  final bool enabled;

  const _PastExamPartMeta({
    required this.label,
    required this.description,
    required this.partKey,
    this.enabled = true,
  });
}