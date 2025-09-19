// lib/screens/score_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../models/answer_history.dart';

// ★ 追加：棒グラフパネル
import '../widgets/score_chart_panel.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});
  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Future<List<AnswerRecord>>? _future;

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.instance.all();
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
          final list = snap.data!;
          final total = list.length;
          final correct = list.where((e) => e.isCorrect).length;
          final rate = total == 0 ? 0.0 : correct * 100.0 / total;

          // 分野ごとの出題数（NULL/空文字は '未指定' に寄せる）
          final Map<String, int> byDomain = {};
          for (final r in list) {
            final d = (r.domain ?? '').trim();
            final key = d.isEmpty ? '未指定' : d;
            byDomain[key] = (byDomain[key] ?? 0) + 1;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatTile(
                  title: '総問題数',
                  value: '$total',
                  sub: '正解 $correct / 正答率 ${rate.toStringAsFixed(1)}%',
                ),

                // ★ ここに棒グラフ（分野別の正答率）を追加
                const ScoreChartPanel(),

                const SizedBox(height: 12),
                const Text(
                  '分野ごとの出題数',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: byDomain.entries
                      .map((e) => Chip(label: Text('${e.key}：${e.value}')))
                      .toList(),
                ),
                const Spacer(),
                AppButtons.primary(
                  label: '成績と履歴を全削除',
                  icon: Icons.delete_outline,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('全削除しますか？'),
                        content: const Text('成績と解答履歴をすべて削除します。元に戻せません。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除'),
                          ),
                        ],
                      ),
                    ) ??
                        false;
                    if (!ok) return;
                    await AnswerHistory.instance.clear();
                    setState(() => _future = AnswerHistory.instance.all());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final String? sub;
  const _StatTile({required this.title, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(sub!, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}