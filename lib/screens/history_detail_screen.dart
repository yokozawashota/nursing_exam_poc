// lib/screens/history_detail_screen.dart
import 'package:flutter/material.dart';

import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';

class HistoryDetailScreen extends StatelessWidget {
  final AnswerRecord record;
  const HistoryDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final d = (record.domain ?? '').isEmpty ? '未指定' : record.domain!;
    final when =
        '${record.ts.year.toString().padLeft(4, '0')}/${record.ts.month.toString().padLeft(2, '0')}/${record.ts.day.toString().padLeft(2, '0')} '
        '${record.ts.hour.toString().padLeft(2, '0')}:${record.ts.minute.toString().padLeft(2, '0')}';

    final labels = record.choices.keys.toList()..sort();
    final sel = record.userAnswers.toSet();
    final cor = record.correctAnswers.toSet();

    return BaseScaffold(
      title: '履歴詳細',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$when ・ ${record.difficulty} ・ $d',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),

              const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(record.question, style: const TextStyle(fontSize: 16)),

              const SizedBox(height: 16),
              const Text('選択肢', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ...labels.map((k) {
                final text = record.choices[k]!;
                final selected = sel.contains(k);
                final correct = cor.contains(k);

                final Color border;
                final Color? fill;
                IconData? leadingIcon;

                if (correct && selected) {
                  border = Colors.teal;
                  fill = Colors.teal.withOpacity(0.10);
                  leadingIcon = Icons.check_circle;
                } else if (correct && !selected) {
                  border = Colors.orange;
                  fill = Colors.orange.withOpacity(0.10);
                  leadingIcon = Icons.info;
                } else if (selected && !correct) {
                  border = Colors.red;
                  fill = Colors.red.withOpacity(0.08);
                  leadingIcon = Icons.cancel;
                } else {
                  border = Colors.black12;
                  fill = null;
                  leadingIcon = null;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leadingIcon != null)
                          Icon(leadingIcon, size: 20, color: border),
                        if (leadingIcon != null) const SizedBox(width: 6),
                        Text(k, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    title: Text(text),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Text('解説', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text((record.explanation ?? '').isEmpty ? '—' : record.explanation!),

              if (record.rationales != null && record.rationales!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('各選択肢の理由', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...record.rationales!.entries.map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('【${e.key}】 ${e.value}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}