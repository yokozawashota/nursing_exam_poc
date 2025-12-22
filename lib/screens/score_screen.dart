// lib/screens/score_screen.dart
import 'package:flutter/material.dart';

import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/history_charts.dart'; // MiniBarChart / buildBarItemsFromStatMap
import '../widgets/exam_score_summary_card.dart';
import '../theme/app_theme.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<AnswerRecord>> _future;

  String _filter = 'すべて'; // 'すべて' / '直近1週間' / '直近1ヶ月'

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.instance.all();

    // カード表示用のフェード＋スライドアニメーション
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AnswerHistory.instance.all();
    });
    await _future;
  }

  List<AnswerRecord> _applyFilter(List<AnswerRecord> items) {
    final now = DateTime.now();
    switch (_filter) {
      case '直近1週間':
        final from7 = now.subtract(const Duration(days: 7));
        return items.where((r) => r.ts.isAfter(from7)).toList();
      case '直近1ヶ月':
        final from30 = now.subtract(const Duration(days: 30));
        return items.where((r) => r.ts.isAfter(from30)).toList();
      default:
        return items; // すべて
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '成績',
      body: FutureBuilder<List<AnswerRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('読み込みに失敗しました: ${snap.error}'),
              ),
            );
          }

          final allItems = snap.data ?? const <AnswerRecord>[];

          // ★ AI学習成績のみを対象（過去問はスコア画面では扱わない）
          final trainingItems =
          allItems.where((r) => r.sourceType != 'past_exam').toList();

          final filteredTraining = _applyFilter(trainingItems);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildFilterDropdown(),
                const SizedBox(height: 16),
                if (filteredTraining.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('該当する解答履歴がありません')),
                  )
                else
                  _buildTrainingContent(filteredTraining),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================
  //  トレーニング成績（AI問題）
  // ============================

  Widget _buildTrainingContent(List<AnswerRecord> items) {
    final theme = Theme.of(context);

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
      byDifficultyDomain[diff]!
          .putIfAbsent(dom, () => {'total': 0, 'correct': 0});
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

    // ===== 上段：国試スコアカード + テキスト統計カード =====
    final totalStat = _StatCard(
      title: '総合成績',
      lines: [
        '解答数：$total',
        '正解数：$correct',
        '正答率：${(rate * 100).toStringAsFixed(1)}%',
      ],
    );

    final diffLines = byDifficulty.entries.map((e) {
      final t = e.value['total'] ?? 0;
      final c = e.value['correct'] ?? 0;
      final r = t == 0 ? 0.0 : c / t;
      return '${e.key}：$c / $t（${(r * 100).toStringAsFixed(1)}%）';
    }).toList();

    final diffStat = _StatCard(title: '出題形式別', lines: diffLines);

    final topRow = LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: totalStat),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: diffStat),
            ],
          );
        } else {
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

    final trendCard = _buildTrendCard(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ★ 国試スコア（目安）カード
        ExamScoreSummaryCard(records: items),
        const SizedBox(height: 16),

        FadeTransition(
          opacity: _animController,
          child: SlideTransition(
            position: _slideAnim,
            child: topRow,
          ),
        ),

        const SizedBox(height: 16),

        if (trendCard != null) ...[
          FadeTransition(
            opacity: _animController,
            child: SlideTransition(
              position: _slideAnim,
              child: trendCard,
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 24),

        // ===== 分野別成績 =====
        Text('分野別成績', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _expansionCard(
          title: '正答率（分野別）',
          child: MiniBarChart(
            title: null,
            items: buildBarItemsFromStatMap(byDomain),
            barHeight: 20,
            maxItems: 10,
          ),
        ),

        const SizedBox(height: 16),

        // ===== 出題形式 × 分野 =====
        Text('出題形式 × 分野', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _expansionCard(
          title: '出題形式ごとの分野別正答率',
          child: Column(
            children: diffKeys.map((diff) {
              final domainStats =
                  byDifficultyDomain[diff] ?? const <String, Map<String, int>>{};
              if (domainStats.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$diff：データなし'),
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

  /// 日毎の正答率推移カード（直近10日分）
  Widget? _buildTrendCard(List<AnswerRecord> items) {
    if (items.isEmpty) return null;

    final buckets = <DateTime, _TrendBucket>{};
    for (final r in items) {
      final day = DateTime(r.ts.year, r.ts.month, r.ts.day);
      final bucket = buckets.putIfAbsent(day, () => _TrendBucket());
      bucket.total++;
      if (r.isCorrect) bucket.correct++;
    }

    var keys = buckets.keys.toList()..sort();
    const maxDays = 10;
    if (keys.length > maxDays) {
      keys = keys.sublist(keys.length - maxDays);
    }

    final points = <_TrendPoint>[];
    for (final d in keys) {
      final b = buckets[d]!;
      final acc = b.total == 0 ? 0.0 : b.correct / b.total;
      final label = '${d.month}/${d.day}';
      points.add(_TrendPoint(label: label, accuracy: acc));
    }

    if (points.isEmpty) return null;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正答率の推移（直近${points.length}日）',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final value = p.accuracy.clamp(0.0, 1.0);
                final heightFactor = value == 0 ? 0.05 : value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.label,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                        Text(
                          '${(p.accuracy * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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

  /// カード風 ExpansionTile
  Widget _expansionCard({required String title, required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: false,
          children: [
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...lines.map((l) => Text(l)).toList(),
        ],
      ),
    );
  }
}

class _TrendBucket {
  int total = 0;
  int correct = 0;
}

class _TrendPoint {
  final String label;
  final double accuracy;

  _TrendPoint({required this.label, required this.accuracy});
}