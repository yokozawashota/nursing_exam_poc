// lib/widgets/result_block.dart
import 'package:flutter/material.dart';
import 'choice_tile.dart';

/// 解答結果の表示用ブロック。
/// - 選択肢の配色ルールは ChoiceTile に統一（正答=薄緑／誤答で選択=薄赤／その他=通常）
/// - 「解説」「根拠」は枠/背景なしのプレーンテキストで表示
class ResultBlock extends StatelessWidget {
  const ResultBlock({
    super.key,
    required this.question,
    required this.choices,           // { 'A': '...', ... }
    required this.selectedAnswers,   // 例 ['B','D']
    required this.correctAnswers,    // 例 ['C','E']
    required this.explanation,
    this.rationales,                 // 例 { 'A': '...', 'B': '...' }
    this.questionKind,               // 'single' | 'multiple' | 'select_incorrect'（任意）
  });

  final String question;
  final Map<String, String> choices;
  final List<String> selectedAnswers;
  final List<String> correctAnswers;
  final String explanation;
  final Map<String, String>? rationales;

  /// 画面上の表示には必須ではないが、将来の注記や整合チェックに使えるよう受け取る
  final String? questionKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final orderedKeys =
    ['A', 'B', 'C', 'D', 'E'].where((k) => choices.containsKey(k)).toList();
    final selected = selectedAnswers.toSet();
    final correct  = correctAnswers.toSet();

    ChoiceTileState stateOf(String label) {
      if (correct.contains(label)) return ChoiceTileState.correct;
      if (selected.contains(label)) return ChoiceTileState.incorrect;
      return ChoiceTileState.normal;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 問題文（枠/背景なし）
        Text(question, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),

        // 選択肢（ChoiceTileで統一）
        for (final k in orderedKeys) ...[
          ChoiceTile(
            label: k,
            text: choices[k]!,
            state: stateOf(k),
            onTap: null, // 結果表示なのでタップなし
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 16),

        // 解答（枠/背景なし）
        Text(
          '解答',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'あなたの選択：${selectedAnswers.join('、')}／正解：${correctAnswers.join('、')}',
          style: theme.textTheme.bodyLarge,
        ),

        // 解説（枠/背景なし）
        if (explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '解説',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(explanation.trim(), style: theme.textTheme.bodyLarge),
        ],

        // 根拠（枠/背景なし・プレーンテキスト）
        if (rationales != null && rationales!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '根拠',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final k in orderedKeys.where((e) => rationales!.containsKey(e)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$k  ',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Expanded(
                    child: Text(
                      rationales![k]!.trim(),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}