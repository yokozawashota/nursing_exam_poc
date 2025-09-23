// lib/screens/result_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../widgets/result_block.dart';

class ResultScreen extends StatelessWidget {
  final String question;
  final Map<String, String> choices;

  // —— 新API（複数対応）
  final List<String>? selectedAnswers; // 例: ['A','C']
  final List<String>? correctAnswers;  // 例: ['A','C']

  // —— 旧API（単一対応・後方互換）
  final String? selectedAnswer;        // 例: 'B'
  final String? correctAnswer;         // 例: 'A'

  final String explanation;            // 解説
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
    // 新API（複数）
    this.selectedAnswers,
    this.correctAnswers,
    // 旧API（単一）
    this.selectedAnswer,
    this.correctAnswer,
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
    // 実際にResultBlockへ渡す集合（旧/新どちらでもOK）
    final List<String>? selectedList =
        selectedAnswers ?? (selectedAnswer != null ? [selectedAnswer!] : null);
    final List<String>? correctList =
        correctAnswers ?? (correctAnswer != null ? [correctAnswer!] : null);

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
                // 複数対応で渡す（内部で旧APIにも互換あり）
                selectedAnswers: selectedList,
                correctAnswers: correctList,
                // 念のため旧APIも併せて渡しておく（互換継続）
                selectedAnswer: selectedAnswer,
                correctAnswer: correctAnswer,
                explanation: explanation,
                rationales: rationales,
              ),
              const SizedBox(height: 16),

              // 遷移する「次の問題を生成」ボタン（これを残す）
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

              // 出題に戻る
              Row(
                children: [
                  Expanded(
                    child: AppButtons.primary(
                      label: '出題に戻る',
                      icon: Icons.arrow_back,
                      onPressed: () {
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