// lib/screens/history_detail_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../models/answer_history.dart';

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.record});
  final AnswerRecord record;

  @override
  Widget build(BuildContext context) {
    final header =
    [record.domain, record.major, record.mid].where((e) => (e ?? '').isNotEmpty).join(' / ');

    return BaseScaffold(
      title: '解答詳細',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header.isNotEmpty) ...[
              Text(header, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Chip(
                  label: Text(record.difficulty),
                  backgroundColor: Colors.black12,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(record.isCorrect ? '正解' : '不正解'),
                  backgroundColor:
                  (record.isCorrect ? Colors.teal : Colors.red).withOpacity(.15),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(record.question, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            const Text('選択肢', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...['A', 'B', 'C', 'D']
                .where(record.choices.containsKey)
                .map((k) {
              final text = record.choices[k]!;
              final selected = record.userAnswer == k;
              final correct = record.correct == k;
              Color? bg;
              if (correct) bg = Colors.teal.withOpacity(.12);
              if (selected && !correct) bg = Colors.red.withOpacity(.08);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Text(k,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  title: Text(text),
                  trailing: correct
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : (selected
                      ? const Icon(Icons.close, color: Colors.red)
                      : null),
                ),
              );
            }),

            const SizedBox(height: 12),
            const Text('解説', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text((record.explanation ?? '').isEmpty ? '—' : record.explanation!),

            if (record.rationales != null && record.rationales!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('各選択肢の理由',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...record.rationales!.entries.map(
                    (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}. ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(e.value)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}