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
  Future<List<AnswerRecord>>? _future;

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.instance.all();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '解答履歴',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('履歴を全削除しますか？'),
                content: const Text('元に戻せません。'),
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
      body: FutureBuilder<List<AnswerRecord>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('履歴はまだありません'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = items[i];
              final d = (r.domain ?? '').isEmpty ? '未指定' : r.domain!;
              final when =
                  '${r.ts.year.toString().padLeft(4, '0')}/${r.ts.month.toString().padLeft(2, '0')}/${r.ts.day.toString().padLeft(2, '0')} '
                  '${r.ts.hour.toString().padLeft(2, '0')}:${r.ts.minute.toString().padLeft(2, '0')}';

              return ListTile(
                leading: Icon(
                  r.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: r.isCorrect ? Colors.teal : Colors.red,
                ),
                title: Text(d),
                subtitle: Text('$when ・ ${r.difficulty}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryDetailScreen(record: r),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}