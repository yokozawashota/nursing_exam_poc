// lib/features/score/widgets/score_chart_panel.dart
import 'package:flutter/material.dart';

import '../../history/services/history_answer_service.dart';
import '../../history/models/history_models.dart';
import '../services/score_history_stats.dart';
import 'score_history_charts.dart';

/// 成績画面などに配置できる、分野別正答率の棒グラフパネル。
///
/// 画面側は `const ScoreChartPanel()` を配置するだけで使える。
/// 内部で解答履歴を読み込み、HistoryRecord へ最小変換したうえで
/// 分野別統計を作成し、MiniBarChart に渡して表示する。
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
          return const SizedBox.shrink();
        }

        final answers = snap.data!;

        // AnswerRecord → HistoryRecord へ最小情報で変換
        final records = answers.map((r) {
          return HistoryRecord(
            timestamp: r.ts,
            difficulty: r.difficulty,
            domain: r.domain ?? '未指定',
            major: '',
            mid: null,
            topic: null,
            correct: r.isCorrect,
            elapsedMs: null,
          );
        }).toList();

        // 分野別に要約 → MiniBarChart アイテムへ
        final summaries = HistoryStats.domainSummaries(records);
        if (summaries.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = buildBarItemsFromDomainSummaries(summaries);

        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
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