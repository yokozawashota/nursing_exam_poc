// lib/screens/past_exam/past_exam_my_answer_detail_screen.dart
import 'package:flutter/material.dart';

import '../../models/past_exam_history.dart';
import '../../theme/app_theme.dart';
import '../../widgets/base_scaffold.dart';

class PastExamMyAnswerDetailScreen extends StatelessWidget {
  const PastExamMyAnswerDetailScreen({
    super.key,
    required this.record,
  });

  final PastExamAnswerRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!record.hasSnapshot) {
      return BaseScaffold(
        title: '解答の詳細',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('この解答には復習用データ（問題文/選択肢）が保存されていません。'),
          ),
        ),
      );
    }

    final choices = record.choices ?? const <String, String>{};
    final correct = (record.correctLabels ?? const <String>[]).toSet();
    final selected = (record.selectedLabels ?? const <String>[]).toSet();

    // 根拠（choiceRationales）: Map<label, rationale>
    final rationales = record.rationales ?? const <String, String>{};

    return BaseScaffold(
      title: '解答の詳細',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.examTitle ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.partLabel ?? ''}${(record.questionNo ?? 0) > 0 ? ' ・ 第${record.questionNo}問' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // 問題文
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Text(
                    record.questionText ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),

                // 画像
                if (record.hasImage) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.asset(
                          record.imagePath!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '画像を読み込めません: ${record.imagePath}',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 選択肢（根拠はここでは出さない）
                ...choices.entries.map((e) {
                  final label = e.key;
                  final text = e.value;

                  final isCorrect = correct.contains(label);
                  final isSelected = selected.contains(label);

                  Color border = Colors.black12;
                  Color bg = theme.colorScheme.surface;

                  if (isCorrect) {
                    border = Colors.green.withOpacity(0.7);
                    bg = Colors.green.withOpacity(0.06);
                  }
                  if (isSelected && !isCorrect) {
                    border = Colors.red.withOpacity(0.7);
                    bg = Colors.red.withOpacity(0.05);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(text)),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // 解説（従来通り）
                if ((record.explanation ?? '').trim().isNotEmpty) ...[
                  Text('解説', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    record.explanation!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: 14),
                ],

                // ✅ 根拠（解説の下・解説と同フォント）
                if (rationales.isNotEmpty) ...[
                  Text('根拠', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),

                  // ラベル順に並べたいので choices の順で出す（無いものはスキップ）
                  ...choices.keys.map((label) {
                    final r = (rationales[label] ?? '').trim();
                    if (r.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '$label：$r',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}