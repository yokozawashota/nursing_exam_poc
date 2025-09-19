import 'package:flutter/material.dart';

/// 解答結果の表示ブロック（表示専用）
/// - 正誤判定や次問生成などのロジックは保持しない
/// - 見た目は現行の結果表示を踏襲（丸囲みや右端丸は使わないカード風）
class ResultBlock extends StatelessWidget {
  final String question;
  final Map<String, String> choices;       // {'A':'...', 'B':'...'}
  final String selectedAnswer;             // 'A'..'D'
  final String correctAnswer;              // 'A'..'D'
  final String explanation;                // 解説
  final Map<String, String>? rationales;   // 任意: {'A':'...', ...}

  const ResultBlock({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.explanation,
    this.rationales,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = selectedAnswer.toUpperCase().trim() ==
        correctAnswer.toUpperCase().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 見出し
        const Text(
          '解答結果',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // 正誤バッジ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCorrect ? Colors.teal.withOpacity(0.12) : Colors.red.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isCorrect ? Colors.teal : Colors.redAccent),
          ),
          child: Row(
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.teal : Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '正解です！' : '不正解です',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCorrect ? Colors.teal.shade800 : Colors.red.shade800,
                ),
              ),
              const Spacer(),
              Text('正答: $correctAnswer'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 問題文
        const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          question,
          style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP', height: 1.45),
        ),

        const SizedBox(height: 16),

        // 選択肢: A〜Dのみ表示、空文字は非表示
        ...['A', 'B', 'C', 'D'].where((k) => choices.containsKey(k)).map((k) {
          final t = (choices[k] ?? '').trim();
          if (t.isEmpty) return const SizedBox.shrink();

          final bool isCorrectChoice = k == correctAnswer;
          final bool isSelectedWrong = (k == selectedAnswer) && !isCorrectChoice;

          Color border = Colors.black12;
          Color? bg;
          if (isCorrectChoice) {
            border = Colors.teal;
            bg = Colors.teal.withOpacity(0.08);
          } else if (isSelectedWrong) {
            border = Colors.redAccent;
            bg = Colors.red.withOpacity(0.06);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Text(
                k,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              title: Text(t),
              trailing: isCorrectChoice
                  ? const Icon(Icons.check, color: Colors.teal)
                  : (isSelectedWrong ? const Icon(Icons.close, color: Colors.redAccent) : null),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          );
        }),

        const SizedBox(height: 16),

        // 解説
        if (explanation.trim().isNotEmpty) ...[
          const Text('解説', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.035),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              explanation,
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 各選択肢の理由（ある場合のみ）
        if (rationales != null && rationales!.isNotEmpty) ...[
          const Text('各選択肢の理由', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...['A', 'B', 'C', 'D'].where((k) => rationales!.containsKey(k)).map((k) {
            final r = (rationales![k] ?? '').trim();
            if (r.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}