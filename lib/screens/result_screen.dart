// lib/screens/result_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../widgets/result_block.dart';

class ResultScreen extends StatelessWidget {
  final String question;
  final Map<String, String> choices;     // {'A':'...', 'B':'...'}
  final String selectedAnswer;           // 'A'..'D'
  final String correctAnswer;            // 'A'..'D'
  final String explanation;              // 解説
  final Map<String, String>? rationales; // 任意: {'A':'...', ...}

  // 次の問題を生成（QuestionScreen 側から渡される）
  final VoidCallback onGenerateNext;

  // 履歴保存メタ（従来の引数をそのまま維持）
  final String? difficulty;
  final String? domain;
  final String? major;
  final String? mid;
  final String? topic;

  const ResultScreen({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.explanation,
    this.rationales,
    required this.onGenerateNext,
    this.difficulty,
    this.domain,
    this.major,
    this.mid,
    this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '解答結果',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 表示専用ブロック
              ResultBlock(
                question: question,
                choices: choices,
                selectedAnswer: selectedAnswer,
                correctAnswer: correctAnswer,
                explanation: explanation,
                rationales: rationales,
              ),
              const SizedBox(height: 16),

              // ボタン群（導線はご要望に合わせて調整）
              Row(
                children: [
                  Expanded(
                    child: AppButtons.success(
                      label: '次の問題を生成',
                      icon: Icons.refresh,
                      onPressed: () {
                        // 次問生成 → 結果画面を閉じて出題画面に戻る
                        onGenerateNext();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButtons.primary(
                      label: '出題に戻る',          // ← ラベル変更
                      icon: Icons.arrow_back,     // ← 戻るアイコンに変更（任意）
                      onPressed: () {
                        // 1画面だけ戻る → QuestionScreenへ
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}