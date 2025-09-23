// lib/screens/score_screen.dart
import 'package:flutter/material.dart';

import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/history_charts.dart'; // MiniBarChart / buildBarItemsFromStatMap

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Future<List<AnswerRecord>>? _future;
  String _filter = 'すべて';

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.instance.all();
  }

  List<AnswerRecord> _applyFilter(List<AnswerRecord> items) {
    final now = DateTime.now();
    if (_filter == '直近1週間') {
      final from = now.subtract(const Duration(days: 7));
      return items.where((r) => r.ts.isAfter(from)).toList();
    } else if (_filter == '直近1ヶ月') {
      final from = DateTime(now.year, now.month - 1, now.day);
      return items.where((r) => r.ts.isAfter(from)).toList();
    }
    return items; // すべて
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '成績',
      body: FutureBuilder<List<AnswerRecord>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snap.data!;
          final items = _applyFilter(allItems);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildFilterDropdown(),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('該当する解答履歴がありません')),
                )
              else
                _buildContent(items),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(List<AnswerRecord> items) {
    // ===== 集計 =====
    final total = items.length;
    final correct = items.where((r) => r.isCorrect).length;
    final rate = (total == 0) ? 0.0 : (correct / total);

    // 出題形式別
    final byDifficulty = <String, Map<String, int>>{};
    for (final r in items) {
      byDifficulty.putIfAbsent(r.difficulty, () => {'total': 0, 'correct': 0});
      byDifficulty[r.difficulty]!['total'] =
          (byDifficulty[r.difficulty]!['total'] ?? 0) + 1;
      if (r.isCorrect) {
        byDifficulty[r.difficulty]!['correct'] =
            (byDifficulty[r.difficulty]!['correct'] ?? 0) + 1;
      }
    }

    // 分野別
    final byDomain = <String, Map<String, int>>{};
    for (final r in items) {
      final dom = (r.domain == null || r.domain!.isEmpty) ? '未指定' : r.domain!;
      byDomain.putIfAbsent(dom, () => {'total': 0, 'correct': 0});
      byDomain[dom]!['total'] = (byDomain[dom]!['total'] ?? 0) + 1;
      if (r.isCorrect) {
        byDomain[dom]!['correct'] = (byDomain[dom]!['correct'] ?? 0) + 1;
      }
    }

    // 出題形式 × 分野
    final byDifficultyDomain = <String, Map<String, Map<String, int>>>{};
    for (final r in items) {
      final diff = r.difficulty;
      final dom = (r.domain == null || r.domain!.isEmpty) ? '未指定' : r.domain!;
      byDifficultyDomain.putIfAbsent(diff, () => <String, Map<String, int>>{});
      byDifficultyDomain[diff]!.putIfAbsent(dom, () => {'total': 0, 'correct': 0});
      byDifficultyDomain[diff]![dom]!['total'] =
          (byDifficultyDomain[diff]![dom]!['total'] ?? 0) + 1;
      if (r.isCorrect) {
        byDifficultyDomain[diff]![dom]!['correct'] =
            (byDifficultyDomain[diff]![dom]!['correct'] ?? 0) + 1;
      }
    }

    const diffOrder = ['必修問題', '一般問題', '状況設定問題'];
    final diffKeys = [
      ...diffOrder.where((k) => byDifficultyDomain.containsKey(k)),
      ...byDifficultyDomain.keys.where((k) => !diffOrder.contains(k)).toList()
        ..sort(),
    ];

    // ===== 上段：総合成績 と 出題形式別（横並び／狭ければ縦） =====
    final totalStat = _StatBlock(
      title: '総合成績',
      lines: [
        '解答数: $total',
        '正解数: $correct',
        '正答率: ${(rate * 100).toStringAsFixed(1)}%',
      ],
    );

    final diffLines = byDifficulty.entries.map((e) {
      final t = e.value['total'] ?? 0;
      final c = e.value['correct'] ?? 0;
      final r = t == 0 ? 0.0 : c / t;
      return '${e.key} : $c / $t （${(r * 100).toStringAsFixed(1)}%）';
    }).toList();

    final diffStat = _StatBlock(title: '出題形式別', lines: diffLines);

    final topRow = LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          // 縦：Expandedは使わない（ParentDataの混在を避ける）
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              totalStat,
              const SizedBox(height: 16),
              diffStat,
            ],
          );
        } else {
          // 横：Row内でだけExpandedを使う
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: totalStat),
              const SizedBox(width: 16),
              Expanded(child: diffStat),
            ],
          );
        }
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topRow,

        const Divider(height: 32),

        // ===== 分野別（折りたたみ・枠なし） =====
        _expansion(
          title: '分野別成績',
          child: MiniBarChart(
            title: '正答率（分野別）',
            items: buildBarItemsFromStatMap(byDomain),
            barHeight: 20,
            maxItems: 10,
          ),
        ),

        const SizedBox(height: 8),

        // ===== 出題形式 × 分野（折りたたみ・枠なし） =====
        _expansion(
          title: '出題形式 × 分野',
          child: Column(
            children: diffKeys.map((diff) {
              final domainStats =
                  byDifficultyDomain[diff] ?? const <String, Map<String, int>>{};
              if (domainStats.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$diff : データなし'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MiniBarChart(
                  title: '$diff の分野別正答率',
                  items: buildBarItemsFromStatMap(domainStats),
                  barHeight: 18,
                  maxItems: 8,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Row(
      children: [
        const Text('表示期間: '),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _filter,
          items: const [
            DropdownMenuItem(value: 'すべて', child: Text('すべて')),
            DropdownMenuItem(value: '直近1週間', child: Text('直近1週間')),
            DropdownMenuItem(value: '直近1ヶ月', child: Text('直近1ヶ月')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _filter = val);
          },
        ),
      ],
    );
  }

  /// 枠なしの ExpansionTile（デフォルト閉）
  Widget _expansion({required String title, required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// シンプルなテキスト統計ブロック（枠なし）
class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        ...lines.map((l) => Text(l)).toList(),
      ],
    );
  }
}