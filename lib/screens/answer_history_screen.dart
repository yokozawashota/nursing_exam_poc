import 'package:flutter/material.dart';
import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';
import 'history_detail_screen.dart';

class AnswerHistoryScreen extends StatefulWidget {
  const AnswerHistoryScreen({super.key});

  @override
  State<AnswerHistoryScreen> createState() => _AnswerHistoryScreenState();
}

class _AnswerHistoryScreenState extends State<AnswerHistoryScreen> {
  late Future<List<AnswerRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.all(); // 既存の挙動を維持
  }

  Future<void> _reload() async {
    final data = await AnswerHistory.all();
    if (!mounted) return;
    setState(() {
      _future = Future.value(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '解答履歴',
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

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('履歴はまだありません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              // 新しい順
              final r = items[items.length - 1 - i];
              return ListTile(
                leading: Icon(
                  r.correct ? Icons.check_circle : Icons.cancel,
                  color: r.correct ? Colors.teal : Colors.redAccent,
                ),
                title: Text(r.category),
                subtitle: Text('${_fmt(r.at)} ・ ${r.form}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // ✅ 詳細画面へ遷移（UIのトーンは維持）
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryDetailScreen(record: r),
                    ),
                  );
                  if (!mounted) return;
                  _reload(); // 戻ってきたら一応最新化
                },
              );
            },
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep),
          tooltip: '履歴を全てクリア',
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
              if (mounted) _reload();
            }
          },
        ),
      ],
    );
  }
}

String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}