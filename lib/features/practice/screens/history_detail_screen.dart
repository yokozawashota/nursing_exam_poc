// lib/features/practice/screens/history_detail_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/models/answer_history.dart';
import '../../../shared/widgets/base_scaffold.dart';
import '../../../shared/widgets/choice_tile.dart';

class HistoryDetailScreen extends StatelessWidget {
  final AnswerRecord record;
  const HistoryDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 画面上の状態判定：ユーザー選択 / 正解
    final userSet = record.userAnswers.toSet();
    final correctSet = record.correctAnswers.toSet();

    // タイトル行（問題タイプなど）
    final String kindLabel = _kindLabel(record.questionKind);

    // 全体の正誤チップ表示
    final bool overallCorrect = record.isCorrect;
    final chipColor = overallCorrect ? Colors.green : Colors.red;
    final chipText = overallCorrect ? '正解' : '不正解';

    final hasChoices = record.choices.isNotEmpty;

    return BaseScaffold(
      title: '解答履歴 詳細',
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== 上部：問題タイプ ＋ 正誤チップ =====
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.surfaceVariant,
                      ),
                      child: Text(
                        kindLabel,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(chipText, style: const TextStyle(color: Colors.white)),
                      backgroundColor: chipColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ===== メタ情報（分野など） =====
                _metaInfoRow('分野', record.domain),
                _metaInfoRow('科目', record.major),
                _metaInfoRow('中項目', record.mid),
                _metaInfoRow('トピック', record.topic),
                _metaInfoRow('日時', _formatTs(record.ts)),
                const SizedBox(height: 20),

                // ===== 問題文（枠なし・背景なし） =====
                if ((record.question).trim().isNotEmpty) ...[
                  Text(
                    record.question.trim(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                ],

                // ===== 選択肢（共通 ChoiceTile） =====
                if (hasChoices)
                  ..._buildChoiceTiles(
                    context: context,
                    choices: record.choices,
                    userSet: userSet,
                    correctSet: correctSet,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('選択肢データが見つかりませんでした'),
                  ),

                const SizedBox(height: 16),

                // ===== 解答（見出し＋本文、枠なし） =====
                Text('解答', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  _answerLine(record.questionKind, record.correctAnswers),
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 16),

                // ===== 解説（枠なし・背景なし） =====
                if ((record.explanation ?? '').trim().isNotEmpty) ...[
                  Text('解説', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(record.explanation!.trim(), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                ],

                // ===== 根拠（ラショナーレ）箇条書き、枠なし =====
                if (record.rationales != null && record.rationales!.isNotEmpty) ...[
                  Text('根拠', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._buildRationales(context, record.rationales!, record.choices),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // ビルド補助
  // -----------------------------

  List<Widget> _buildChoiceTiles({
    required BuildContext context,
    required Map<String, String> choices,
    required Set<String> userSet,
    required Set<String> correctSet,
  }) {
    // 表示順は A..E
    final order = const ['A', 'B', 'C', 'D', 'E'];
    final labels = order.where((label) => choices.containsKey(label));

    return labels.map((label) {
      final text = (choices[label] ?? '').trim();
      final bool isCorrect = correctSet.contains(label);
      final bool isSelected = userSet.contains(label);

      // 履歴画面の「状態色」決定
      // - 正解は常に correct（薄緑）
      // - ユーザーが選んだが正解ではない → incorrect（薄赤）
      // - それ以外 → normal
      final state = isCorrect
          ? ChoiceTileState.correct
          : (isSelected ? ChoiceTileState.incorrect : ChoiceTileState.normal);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChoiceTile(
          label: label,
          text: text,
          state: state,
          onTap: null, // 履歴ではタップ不可
          dense: false,
        ),
      );
    }).toList();
  }

  List<Widget> _buildRationales(
      BuildContext context,
      Map<String, String> rationales,
      Map<String, String> choices,
      ) {
    final theme = Theme.of(context);
    final order = const ['A', 'B', 'C', 'D', 'E'];
    final labels = order.where((label) => choices.containsKey(label));

    return labels.map((label) {
      final rationale = rationales[label]?.trim();
      if (rationale == null || rationale.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(rationale, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }).toList();
  }

  // -----------------------------
  // 表示用ユーティリティ
  // -----------------------------

  String _kindLabel(String? kind) {
    switch ((kind ?? 'single')) {
      case 'multiple':
        return '複数選択問題';
      case 'select_incorrect':
        return '誤答を選ぶ問題';
      default:
        return '単一選択問題';
    }
  }

  String _formatTs(DateTime ts) {
    // シンプルな手動フォーマット（例：2025/10/08 17:05）
    String two(int n) => n.toString().padLeft(2, '0');
    return '${ts.year}/${two(ts.month)}/${two(ts.day)} ${two(ts.hour)}:${two(ts.minute)}';
    // ※ 将来的に intl を入れる場合は DateFormat を使う実装に置き換え可
  }

  /// メタ情報の行（null/空は '—' にフォールバック）
  Widget _metaInfoRow(String title, String? value) {
    final display = (value != null && value.trim().isNotEmpty) ? value.trim() : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  /// 「解答: A, D」などの一行を生成
  String _answerLine(String? kind, List<String> correct) {
    final lbl = (kind == 'select_incorrect') ? '解答（誤っているもの）' : '解答';
    if (correct.isEmpty) return '$lbl: —';
    // A,B,C…の整列
    final order = const ['A', 'B', 'C', 'D', 'E'];
    final set = correct.toSet();
    final ordered = order.where(set.contains).toList();
    return '$lbl: ${ordered.join(', ')}';
  }
}