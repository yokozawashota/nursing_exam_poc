// lib/screens/result_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../widgets/result_block.dart';

class ResultScreen extends StatelessWidget {
  final String question;
  final Map<String, String> choices;

  /// 複数対応（単一の場合も1要素で渡る）
  final List<String> selectedAnswers;
  final List<String> correctAnswers;

  final String explanation;
  final Map<String, String>? rationales;

  /// 次の問題を生成（QuestionScreen 側から渡される）
  final VoidCallback onGenerateNext;

  /// メタ（任意）
  final String? difficulty;
  final String? domain;
  final String? major;
  final String? mid;
  final String? topic;

  /// 問題タイプ（'single' | 'multiple' | 'select_incorrect'）
  /// 渡されない場合は 'single' として扱う（後方互換）
  final String? questionKind;

  const ResultScreen({
    super.key,
    required this.question,
    required this.choices,
    required this.selectedAnswers,
    required this.correctAnswers,
    required this.explanation,
    this.rationales,
    required this.onGenerateNext,
    this.difficulty,
    this.domain,
    this.major,
    this.mid,
    this.topic,
    this.questionKind, // 省略可
  });

  @override
  Widget build(BuildContext context) {
    final kind = questionKind ?? 'single';

    return BaseScaffold(
      title: '解答結果',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResultBlock(
                question: question,
                choices: choices,
                selectedAnswers: selectedAnswers,
                correctAnswers: correctAnswers,
                explanation: explanation,
                rationales: rationales,
                questionKind: kind,
              ),
              const SizedBox(height: 20),

              // 次の問題
              SizedBox(
                width: double.infinity,
                child: AppButtons.success(
                  label: '次の問題を生成',
                  icon: Icons.refresh,
                  onPressed: () {
                    onGenerateNext();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 出題に戻る
              SizedBox(
                width: double.infinity,
                child: AppButtons.primary(
                  label: '出題に戻る',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}