// lib/screens/result_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../models/answer_history.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.explanation,
    this.rationales,
    required this.onGenerateNext,
    // メタ情報（履歴用）
    required this.difficulty,
    this.domain,
    this.major,
    this.mid,
    this.topic,
  });

  final String question;
  final Map<String, String> choices; // A-D
  final String selectedAnswer; // 'A'..'D'
  final String correctAnswer; // 'A'..'D'
  final String explanation;
  final Map<String, String>? rationales;
  final VoidCallback onGenerateNext;

  // meta
  final String difficulty;
  final String? domain;
  final String? major;
  final String? mid;
  final String? topic;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveHistoryOnce();
  }

  Future<void> _saveHistoryOnce() async {
    if (_saved) return;
    _saved = true;
    final rec = AnswerRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ts: DateTime.now(),
      difficulty: widget.difficulty,
      domain: widget.domain,
      major: widget.major,
      mid: widget.mid,
      topic: widget.topic,
      question: widget.question,
      choices: widget.choices,
      correct: widget.correctAnswer,
      explanation: widget.explanation,
      rationales: widget.rationales,
      userAnswer: widget.selectedAnswer,
    );
    await AnswerHistory.instance.add(rec);
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.selectedAnswer == widget.correctAnswer;

    return BaseScaffold(
      title: '結果',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? '正解！' : '不正解',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.teal : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.question, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            const Text('選択肢', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...['A', 'B', 'C', 'D'].where(widget.choices.containsKey).map((k) {
              final text = widget.choices[k]!;
              final selected = widget.selectedAnswer == k;
              final correct = widget.correctAnswer == k;
              Color? tileColor;
              if (correct) tileColor = Colors.teal.withOpacity(0.12);
              if (selected && !correct) tileColor = Colors.red.withOpacity(0.08);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: tileColor,
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
            Text(widget.explanation.isEmpty ? '—' : widget.explanation),

            if (widget.rationales != null &&
                widget.rationales!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('各選択肢の理由',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...widget.rationales!.entries.map(
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

            const SizedBox(height: 24),
            AppButtons.primary(
              label: '次の問題を生成',
              icon: Icons.auto_awesome,
              onPressed: widget.onGenerateNext,
            ),
          ],
        ),
      ),
    );
  }
}