// lib/widgets/result_block.dart
import 'package:flutter/material.dart';

/// 結果表示（単一/複数正答の両対応）
class ResultBlock extends StatelessWidget {
  final String question;
  final Map<String, String> choices;

  // 新API
  final List<String>? selectedAnswers; // 複数対応
  final List<String>? correctAnswers;  // 複数対応

  // 旧API（互換）
  final String? selectedAnswer;
  final String? correctAnswer;

  final String explanation;
  final Map<String, String>? rationales;

  const ResultBlock({
    super.key,
    required this.question,
    required this.choices,
    this.selectedAnswers,
    this.correctAnswers,
    this.selectedAnswer,
    this.correctAnswer,
    required this.explanation,
    required this.rationales,
  });

  @override
  Widget build(BuildContext context) {
    final labels = choices.keys.toList()..sort();

    // 実際に使う集合（旧/新を吸収）
    final sel = (selectedAnswers ??
        (selectedAnswer != null ? <String>[selectedAnswer!] : const <String>[]))
        .toSet();
    final cor = (correctAnswers ??
        (correctAnswer != null ? <String>[correctAnswer!] : const <String>[]))
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          question,
          style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP'),
        ),
        const SizedBox(height: 16),

        const Text('選択肢', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        ...labels.map((k) {
          final text = choices[k]!;
          final isCorrect = cor.contains(k);
          final isSelected = sel.contains(k);

          final Color border;
          final Color? fill;
          IconData? leadingIcon;

          if (isCorrect && isSelected) {
            border = Colors.teal;
            fill = Colors.teal.withOpacity(0.10);
            leadingIcon = Icons.check_circle;
          } else if (isCorrect && !isSelected) {
            border = Colors.orange;
            fill = Colors.orange.withOpacity(0.10);
            leadingIcon = Icons.info;
          } else if (isSelected && !isCorrect) {
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
        Text(explanation.isEmpty ? '—' : explanation),

        if (rationales != null && rationales!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('各選択肢の理由', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...rationales!.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('【${e.key}】 ${e.value}'),
            );
          }),
        ],
      ],
    );
  }
}