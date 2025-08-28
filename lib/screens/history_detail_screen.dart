import 'package:flutter/material.dart';
import '../models/answer_history.dart';
import '../widgets/base_scaffold.dart';

class HistoryDetailScreen extends StatelessWidget {
  final AnswerRecord record;

  const HistoryDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String questionText = (record.questionText ?? '').trim();
    final List<String> choices = (record.choices ?? const <String>[]).toList();
    final int? selectedIdx = record.selectedIndex;
    final int? correctIdx = record.correctIndex;
    final String explanation = (record.explanation ?? '').trim();

    return BaseScaffold(
      title: '履歴詳細',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // メタ情報
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('日時', _fmt(record.at)),
                    const SizedBox(height: 8),
                    _kv('分野', record.category),
                    const SizedBox(height: 8),
                    _kv('形式', record.form),
                    const SizedBox(height: 8),
                    _kv('結果', record.correct ? '正解' : '不正解',
                        style: theme.textTheme.titleMedium),
                    if ((record.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(record.note!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 問題
          if (questionText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(questionText, style: theme.textTheme.titleMedium),
              ),
            ),
          ],

          // 選択肢
          if (choices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    dense: true,
                    leading: Icon(Icons.format_list_bulleted),
                    title: Text('選択肢'),
                  ),
                  const Divider(height: 1),
                  ...List.generate(choices.length, (i) {
                    final label = String.fromCharCode('A'.codeUnitAt(0) + i);
                    final text = choices[i];
                    final isCorrect = (correctIdx != null && i == correctIdx);
                    final isSelected = (selectedIdx != null && i == selectedIdx);

                    Color? tileColor;
                    IconData? icon;
                    if (isCorrect && isSelected) {
                      tileColor = Colors.teal.withOpacity(0.08);
                      icon = Icons.check_circle;
                    } else if (isCorrect) {
                      tileColor = Colors.teal.withOpacity(0.08);
                      icon = Icons.check;
                    } else if (isSelected) {
                      tileColor = Colors.redAccent.withOpacity(0.08);
                      icon = Icons.cancel;
                    }

                    return ListTile(
                      leading: icon != null ? Icon(icon) : const SizedBox.shrink(),
                      title: Text('$label.  $text'),
                      tileColor: tileColor,
                    );
                  }),
                ],
              ),
            ),
          ],

          // 解説
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.menu_book),
                        SizedBox(width: 8),
                        Text('解説', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(explanation, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],

          // スナップショットが無い古い履歴
          if (questionText.isEmpty && choices.isEmpty && explanation.isEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.amber.withOpacity(0.12),
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('この履歴には問題・選択肢・解説の詳細が保存されていません。'),
                subtitle: Text('今後解いた問題から順に詳細が表示されます。'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {TextStyle? style}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: style)),
      ],
    );
  }
}

String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}