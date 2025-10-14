// lib/screens/history_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/choice_tile.dart';

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

    return BaseScaffold(
      title: '解答履歴 詳細',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== メタ情報（分野など） =====
              Text(
                kindLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _metaInfoRow('分野', record.domain),
              _metaInfoRow('科目', record.major),
              _metaInfoRow('中項目', record.mid),
              _metaInfoRow('トピック', record.topic),
              _metaInfoRow('日時', _formatTs(record.ts)),
              const SizedBox(height: 20),

              // ===== 問題文（枠なし・背景なし） =====
              Text(
                record.question,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // ===== 選択肢（共通 ChoiceTile） =====
              ..._buildChoiceTiles(
                context: context,
                choices: record.choices,
                userSet: userSet,
                correctSet: correctSet,
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
    final labels = ['A', 'B', 'C', 'D', 'E'].where(choices.keys.toSet().contains);

    return labels.map((label) {
      final text = choices[label] ?? '';
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
    final labels = ['A', 'B', 'C', 'D', 'E'].where(choices.containsKey);

    return labels.map((label) {
      final rationale = rationales[label]?.trim();
      if (rationale == null || rationale.isEmpty) return const SizedBox.shrink();
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
    final ordered = ['A', 'B', 'C', 'D', 'E'].where(correct.toSet().contains).toList();
    return '$lbl: ${ordered.join(', ')}';
  }
}