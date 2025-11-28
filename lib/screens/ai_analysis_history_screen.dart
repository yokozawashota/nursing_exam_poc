// lib/screens/ai_analysis_history_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../theme/app_theme.dart';
import '../ai_analysis/ai_analysis_history.dart';
import 'ai_analysis_detail_screen.dart';

class AiAnalysisHistoryScreen extends StatefulWidget {
  const AiAnalysisHistoryScreen({super.key});

  @override
  State<AiAnalysisHistoryScreen> createState() =>
      _AiAnalysisHistoryScreenState();
}

class _AiAnalysisHistoryScreenState extends State<AiAnalysisHistoryScreen> {
  late Future<List<AiAnalysisHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = AiAnalysisHistory.instance.all();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AiAnalysisHistory.instance.all();
    });
    await _future;
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴をすべて削除しますか？'),
        content: const Text(
          'AI分析の履歴をすべて削除します。この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除する',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AiAnalysisHistory.instance.clear();
      if (!mounted) return;
      await _reload();
    }
  }

  Future<void> _deleteOne(AiAnalysisHistoryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この分析を削除しますか？'),
        content: Text(
          '「${entry.targetLabel}」の分析（${_formatDate(entry.createdAt)}）を削除します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除する',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AiAnalysisHistory.instance.remove(entry.id);
      if (!mounted) return;
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'AI分析履歴',
      showBack: true,
      showFooter: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: '履歴をすべて削除',
          onPressed: _confirmClearAll,
        ),
      ],
      body: FutureBuilder<List<AiAnalysisHistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('履歴の読み込みに失敗しました：${snap.error}'),
              ),
            );
          }

          final items = snap.data ?? const <AiAnalysisHistoryEntry>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'AI分析の履歴はまだありません。\n\nAI分析画面から分析を実行すると、ここに記録されます。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final e = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AiAnalysisDetailScreen(entry: e),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          e.scope == 'overall'
                              ? Icons.analytics_rounded
                              : Icons.task_alt_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.scope == 'overall'
                                    ? '全体分析'
                                    : '分野分析：${e.targetLabel}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(e.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '回答数：${e.totalAnswers}問　／　正答率：${_pct(e.accuracy)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _deleteOne(e),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}