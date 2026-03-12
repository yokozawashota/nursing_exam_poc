// lib/features/mock_exam/screens/mock_exam_result_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../../history/services/history_answer_service.dart';

class MockExamResultScreen extends StatelessWidget {
  const MockExamResultScreen({
    super.key,
    required this.records,
    required this.totalPlanned,
    required this.answeredCount,
    required this.correctCount,
    required this.usedSeconds,
    required this.timeLimitSeconds,
    required this.finishedByTimeout,
  });

  final List<AnswerRecord> records;
  final int totalPlanned;
  final int answeredCount;
  final int correctCount;
  final int usedSeconds;
  final int timeLimitSeconds;
  final bool finishedByTimeout;

  String _formatTime(int sec) {
    if (sec < 0) sec = 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goBackToConfig(BuildContext context) {
    // pushReplacementで来ているので、popできれば「模試設定」へ戻る想定。
    // もし戻れない場合でも落ちないようにする。
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      _goHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = answeredCount;
    final rate = total == 0 ? 0.0 : correctCount / total;

    return BaseScaffold(
      title: '模試結果',
      // ✅ 戻るボタンを復活（= 模試設定画面へ戻れる）
      showBack: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('おつかれさまでした！', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('結果サマリ', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('回答数: $answeredCount / $totalPlanned'),
                    Text('正解数: $correctCount'),
                    Text('正答率: ${(rate * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    Text('所要時間: ${_formatTime(usedSeconds)}'),
                    if (timeLimitSeconds > 0)
                      Text('制限時間: ${_formatTime(timeLimitSeconds)}'),
                    if (finishedByTimeout)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '※制限時間により終了しました',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '※詳細分析はスコア画面をご確認ください',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),

              // ✅ 追加：戻る導線（ホーム / 模試設定）
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _goBackToConfig(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('模試設定へ戻る'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _goHome(context),
                      icon: const Icon(Icons.home),
                      label: const Text('ホームへ戻る'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}