// lib/features/practice/widgets/score_chart_panel.dart
import 'package:flutter/material.dart';

import '../../../shared/models/answer_history.dart';     // AnswerHistory / AnswerRecord
import '../../../shared/models/history_models.dart';     // HistoryRecord / DomainSummary
import '../services/history_stats.dart';                 // ★ tree準拠（study ではなく practice/services）
import 'history_charts.dart';                            // MiniBarChart / buildBarItemsFromDomainSummaries

/// 成績画面など“どこにでも”置ける、分野別正答率の棒グラフパネル。
/// 画面側は `const ScoreChartPanel()` を配置するだけでOK。
class ScoreChartPanel extends StatelessWidget {
  final String title;
  final int maxItems;

  const ScoreChartPanel({
    super.key,
    this.title = '分野別の正答率',
    this.maxItems = 6,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnswerRecord>>(
      future: AnswerHistory.instance.all(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink(); // 履歴が無いときは非表示
        }
        final answers = snap.data!;

        // AnswerRecord -> HistoryRecord へ最小情報で変換
        final List<HistoryRecord> records = answers.map((r) {
          return HistoryRecord(
            timestamp: r.ts,
            difficulty: r.difficulty,
            domain: (r.domain ?? '未指定'),
            major: '',          // 成績パネルでは未使用のため空でOK
            mid: null,
            topic: null,
            correct: r.isCorrect,
            elapsedMs: null,
          );
        }).toList();

        // 分野別に要約 → MiniBarChart アイテムへ
        final summaries = HistoryStats.domainSummaries(records);
        if (summaries.isEmpty) return const SizedBox.shrink();
        final items = buildBarItemsFromDomainSummaries(summaries);

        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
          child: MiniBarChart(
            title: title,
            items: items.take(maxItems).toList(),
            maxItems: maxItems,
          ),
        );
      },
    );
  }
}