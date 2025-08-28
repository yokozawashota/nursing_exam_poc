import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../models/answer_history.dart';

class ResultScreen extends StatefulWidget {
  final String question;
  final Map<String, String> choices;      // {'A': '...', 'B': '...'}
  final String selectedAnswer;            // 'A'..'D'
  final String correctAnswer;             // 'A'..'D'
  final String explanation;
  final Map<String, String>? rationales;  // 任意
  final VoidCallback onGenerateNext;

  // 保存精度のため（UI影響なし）
  final String category; // 例: '成人看護学' / '必修'
  final String form;     // 例: '必修' / '一般' / '状況設定'

  const ResultScreen({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.explanation,
    required this.onGenerateNext,
    this.rationales,
    this.category = '未指定',
    this.form = '未指定',
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saved = false; // 表示1回につき保存は1度だけ

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_saved) return;
    _saved = true;

    int _letterToIndex(String s) {
      final up = s.trim().toUpperCase();
      return (up.codeUnitAt(0) - 'A'.codeUnitAt(0)).clamp(0, 25);
    }

    final selectedIdx = _letterToIndex(widget.selectedAnswer);
    final correctIdx = _letterToIndex(widget.correctAnswer);
    final isCorrect = selectedIdx == correctIdx;

    // Map -> List<String>（順序は A, B, C, D）
    final choices = ['A', 'B', 'C', 'D']
        .map((k) => widget.choices[k] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    // ✅ 履歴へスナップショット保存（ここに集約）
    AnswerHistory.addSnapshot(
      category: widget.category,
      form: widget.form,
      correct: isCorrect,
      questionId: null,
      note: null,
      questionText: widget.question,
      choices: choices,
      selectedIndex: selectedIdx,
      correctIndex: correctIdx,
      explanation: widget.explanation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = widget.selectedAnswer == widget.correctAnswer;

    return BaseScaffold(
      title: '解答結果',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('問題文：', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.question,
              style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP'),
            ),
            const SizedBox(height: 16),
            Text(
              'あなたの解答：${widget.selectedAnswer}',
              style: TextStyle(
                fontSize: 16,
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('正答：${widget.correctAnswer}', style: const TextStyle(fontSize: 16)),
            const Divider(height: 32),
            const Text('解説：', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.explanation,
              style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP'),
            ),
            if (widget.rationales != null && widget.rationales!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('各選択肢の理由：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...['A', 'B', 'C', 'D'].map((k) {
                final text = widget.rationales![k] ?? '';
                if (text.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$k.  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, height: 1.4)),
                      Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
                    ],
                  ),
                );
              }),
            ],
            const Spacer(),
            AppButtons.success(
              label: '次の問題を生成',
              icon: Icons.refresh,
              onPressed: () {
                Navigator.pop(context);
                widget.onGenerateNext();
              },
            ),
            const SizedBox(height: 10),
            AppButtons.neutral(
              label: 'メニューに戻る',
              icon: Icons.home,
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}