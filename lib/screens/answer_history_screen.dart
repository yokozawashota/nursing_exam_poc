// lib/screens/answer_history_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import '../models/answer_history.dart';
import 'history_detail_screen.dart';

class AnswerHistoryScreen extends StatefulWidget {
  const AnswerHistoryScreen({super.key});

  @override
  State<AnswerHistoryScreen> createState() => _AnswerHistoryScreenState();
}

class _AnswerHistoryScreenState extends State<AnswerHistoryScreen> {
  String _filter = 'すべて';

  List<AnswerRecord> _applyFilter(List<AnswerRecord> items) {
    // 今は「すべて」のみ。将来フィルタ追加時用。
    return items;
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解答履歴を削除'),
        content: const Text('すべての解答履歴を削除します。よろしいですか？'),
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
      await AnswerHistory.instance.clear();
      if (!mounted) return;
      // clear() 内で version がインクリメントされるので、
      // ここで setState しなくても ValueListenableBuilder が再buildされる。
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解答履歴を削除しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '解答履歴',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmClearHistory(context),
        ),
      ],
      body: ValueListenableBuilder<int>(
        valueListenable: AnswerHistory.instance.versionListenable,
        builder: (context, _, __) {
          return FutureBuilder<List<AnswerRecord>>(
            future: AnswerHistory.instance.all(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('解答履歴の読み込みに失敗しました: ${snap.error}'),
                  ),
                );
              }

              final allItems = snap.data ?? const <AnswerRecord>[];
              final items = _applyFilter(allItems);

              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                    children: const [
                      Center(
                        child: Text('解答履歴はまだありません'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final r = items[index];
                    final when = _formatDateTime(r.ts);

                    final leadingIcon = Icon(
                      r.isCorrect
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: r.isCorrect ? Colors.green[600] : Colors.red[500],
                    );

                    final subtitleText = StringBuffer()
                      ..write(when)
                      ..write(' ・ ')
                      ..write(r.difficulty);
                    if (r.domain != null && r.domain!.isNotEmpty) {
                      subtitleText.write(' ・ ${r.domain}');
                    }

                    return ListTile(
                      leading: leadingIcon,
                      title: Text(
                        r.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(subtitleText.toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HistoryDetailScreen(record: r),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}