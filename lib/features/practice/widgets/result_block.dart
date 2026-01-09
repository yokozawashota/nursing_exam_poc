// lib/features/practice/widgets/result_block.dart
import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/choice_tile.dart';
import '../../../shared/widgets/explanation_block.dart';

/// 解答結果の表示ブロック
/// - 問題文/解説・根拠は ExplanationBlock で統一
/// - 正答0件でもUIが崩れないようガード
class ResultBlock extends StatelessWidget {
  const ResultBlock({
    super.key,
    required this.question,
    required this.choices,            // Map<'A'..'E', text>
    required this.selectedAnswers,    // List<'A'..'E'>
    required this.correctAnswers,     // List<'A'..'E'>
    required this.explanation,
    this.rationales,                  // Map<label, text>?
    this.questionKind,                // 'single' | 'multiple' | 'select_incorrect'（任意）
  });

  final String question;
  final Map<String, String> choices;
  final List<String> selectedAnswers;
  final List<String> correctAnswers;
  final String explanation;
  final Map<String, String>? rationales;
  final String? questionKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 表示順は A..E の昇順に統一
    final orderedKeys = ['A', 'B', 'C', 'D', 'E'].where(choices.containsKey).toList();

    final sel = selectedAnswers.toSet();
    final cor = correctAnswers.toSet();

    final isIncorrect = (questionKind ?? '').contains('incorrect');
    final correctCount = cor.length;

    // ===== 正答が0件でも落ちないようフォールバック表示 =====
    if (correctCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplanationBlock(title: '問題', body: question),
          const SizedBox(height: 20),

          Text('選択肢', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...orderedKeys.map((label) {
            final text = choices[label] ?? '';
            final userSelected = sel.contains(label);

            final state = userSelected ? ChoiceTileState.incorrect : ChoiceTileState.normal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceTile(
                label: label,
                text: text,
                state: state,
                dense: true,
              ),
            );
          }),

          const SizedBox(height: 20),
          Text('解答：該当なし', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),
          if (explanation.trim().isNotEmpty)
            ExplanationBlock(title: '解説', body: explanation.trim()),
        ],
      );
    }

    // ===== 通常表示 =====
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 問題
        ExplanationBlock(
          title: '問題',
          body: question,
        ),
        const SizedBox(height: 20),

        // 選択肢
        Text('選択肢', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...orderedKeys.map((label) {
          final text = choices[label] ?? '';
          final userSelected = sel.contains(label);
          final isCorrect = cor.contains(label);

          ChoiceTileState state = ChoiceTileState.normal;
          if (userSelected && isCorrect) {
            state = ChoiceTileState.correct;
          } else if (userSelected && !isCorrect) {
            state = ChoiceTileState.incorrect;
          } else if (!userSelected && isCorrect) {
            state = ChoiceTileState.correct;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceTile(
              label: label,
              text: text,
              state: state,
              dense: true,
            ),
          );
        }),

        const SizedBox(height: 20),

        // 解答の一文
        _answerLine(context, isIncorrect, correctCount, cor),

        const SizedBox(height: 8),

        // 解説
        if (explanation.trim().isNotEmpty) ...[
          ExplanationBlock(
            title: '解説',
            body: explanation.trim(),
          ),
          const SizedBox(height: 20),
        ],

        // 根拠
        if (rationales != null && rationales!.isNotEmpty) ...[
          Text('根拠', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._rationaleTiles(orderedKeys, cor),
        ],
      ],
    );
  }

  /// 「解答：A と D（2つ）」の行
  Widget _answerLine(BuildContext context, bool isIncorrect, int count, Set<String> cor) {
    final theme = Theme.of(context);
    final list = _labelsToJoined(cor.toList()..sort());
    final suffix = count >= 2 ? '（${count}つ）' : '';
    final head = isIncorrect ? '解答（誤っているもの）' : '解答';
    return Text(
      '$head：$list$suffix',
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  /// 根拠のタイル群（ChoiceTile で正誤色を合わせる）
  List<Widget> _rationaleTiles(List<String> orderedKeys, Set<String> cor) {
    final items = <Widget>[];
    for (final k in orderedKeys) {
      final txt = rationales?[k]?.trim() ?? '';
      if (txt.isEmpty) continue;
      final isCorrect = cor.contains(k);
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChoiceTile(
            label: k,
            text: txt,
            state: isCorrect ? ChoiceTileState.correct : ChoiceTileState.incorrect,
            dense: true,
          ),
        ),
      );
    }
    return items;
  }

  /// ['A','C','D'] -> 'A と C と D'
  String _labelsToJoined(List<String> labels) {
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    return [
      ...labels.sublist(0, labels.length - 1).map((e) => e),
      'と ${labels.last}'
    ].join(' ');
  }
}