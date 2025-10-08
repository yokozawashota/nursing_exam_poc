// lib/screens/history_detail_screen.dart
import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/choice_tile.dart';
import '../models/answer_history.dart';

/// 解答履歴の 1 件を詳細表示する画面
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({
    super.key,
    required this.record,
  });

  final AnswerRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final choices = record.choices;
    final selected = record.userAnswers.toSet();
    final correct  = record.correctAnswers.toSet();

    final orderedKeys =
    ['A', 'B', 'C', 'D', 'E'].where((k) => choices.containsKey(k)).toList();

    ChoiceTileState stateOf(String label) {
      if (correct.contains(label)) return ChoiceTileState.correct;
      if (selected.contains(label)) return ChoiceTileState.incorrect;
      return ChoiceTileState.normal;
    }

    return BaseScaffold(
      title: '履歴詳細',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 問題文：枠・背景なし
              Text(record.question, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),

              // 選択肢（ChoiceTileで統一）
              for (final k in orderedKeys) ...[
                ChoiceTile(
                  label: k,
                  text: choices[k]!,
                  state: stateOf(k),
                  onTap: null,
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 20),

              // 解答（プレーン）
              Text('解答',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'あなたの選択：${record.userAnswers.join('、')}／正解：${record.correctAnswers.join('、')}',
                style: theme.textTheme.bodyLarge,
              ),

              // 解説（プレーン）
              if ((record.explanation ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('解説',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  record.explanation!.trim(),
                  style: theme.textTheme.bodyLarge,
                ),
              ],

              // 根拠（枠・背景なし／プレーン）
              if (record.rationales != null && record.rationales!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('根拠',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final key in orderedKeys
                    .where((k) => record.rationales!.containsKey(k))) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$key  ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Expanded(
                          child: Text(
                            record.rationales![key]!.trim(),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}