import 'package:flutter/material.dart';
import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  late Future<HistorySummary> _future; // 再読み込みできるよう finalにしない

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.summary();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'スコア',
      body: FutureBuilder<HistorySummary>(
        future: _future,
        builder: (context, snap) {
          // ローディングは wait 中だけ
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // エラー表示
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('読み込みに失敗しました: ${snap.error}'),
              ),
            );
          }

          final summary = snap.data ??
              const HistorySummary(
                total: 0,
                correct: 0,
                accuracy: 0.0,
                byCategory: {},
                byForm: {},
              );

          // 履歴0件の空状態
          if (summary.total == 0) {
            return _EmptyState(
              title: 'まだスコアはありません',
              subtitle: 'まずは問題を解いて結果を確認しましょう。',
              actionText: '問題へ戻る',
              onPressed: () => Navigator.of(context).pop(),
            );
          }

          // 通常表示
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeadlineCard(summary: summary),
              const SizedBox(height: 16),
              _FormSection(summary: summary),
              const SizedBox(height: 16),
              _CategorySection(summary: summary),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.delete_sweep),
                label: const Text('履歴を全てクリア'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('確認'),
                      content: const Text('履歴を全て削除します。よろしいですか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('キャンセル'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('削除する'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await AnswerHistory.clear();
                    if (mounted) {
                      setState(() {
                        _future = AnswerHistory.summary();
                      });
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  final HistorySummary summary;
  const _HeadlineCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.accuracy * 100).toStringAsFixed(1);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('累計問題数：${summary.total}問',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('正答：${summary.correct}問'),
                    Text('正答率：$pct%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final HistorySummary summary;
  const _FormSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.byForm.isEmpty) {
      return const SizedBox.shrink();
    }
    final tiles = summary.byForm.entries.map((e) {
      final pct = (e.value.accuracy * 100).toStringAsFixed(1);
      return ListTile(
        leading: const Icon(Icons.description),
        title: Text(e.key), // 必修 / 一般 / 状況設定
        subtitle: Text('正答 ${e.value.correct}/${e.value.total}（$pct%）'),
      );
    }).toList();

    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.insights),
            title: Text('形式別スコア（必修 / 一般 / 状況設定）'),
          ),
          const Divider(height: 1),
          ...tiles,
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final HistorySummary summary;
  const _CategorySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.byCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    final tiles = summary.byCategory.entries.map((e) {
      final pct = (e.value.accuracy * 100).toStringAsFixed(1);
      return ListTile(
        leading: const Icon(Icons.folder_open),
        title: Text(e.key),
        subtitle: Text('正答 ${e.value.correct}/${e.value.total}（$pct%）'),
      );
    }).toList();

    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.pie_chart),
            title: Text('分野別スコア'),
          ),
          const Divider(height: 1),
          ...tiles,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(actionText)),
          ],
        ),
      ),
    );
  }
}