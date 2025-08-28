import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nursing_exam_poc/models/answer_history.dart';

void main() {
  setUp(() async {
    // SharedPreferences を毎回まっさらに
    SharedPreferences.setMockInitialValues({});
    await AnswerHistory.clear();
  });

  test('保存→取得→集計→クリアの一連が動く', () async {
    // 初期状態
    var all = await AnswerHistory.all();
    expect(all, isEmpty);

    // 追加1
    await AnswerHistory.add(AnswerRecord(
      category: '成人看護学',
      difficulty: '一般問題',
      correct: true,
      date: DateTime(2025, 1, 1, 12, 0),
    ));

    // 追加2
    await AnswerHistory.add(AnswerRecord(
      category: '成人看護学',
      difficulty: '一般問題',
      correct: false,
      date: DateTime(2025, 1, 2, 9, 30),
    ));

    // 取得
    all = await AnswerHistory.all();
    expect(all.length, 2);
    expect(all.first.category, '成人看護学');

    // 集計
    final stats = await AnswerHistory.calculateStats();
    final overall = stats['overall']!;
    expect(overall['total'], 2);
    expect(overall['correct'], 1);

    // 難易度別/カテゴリ別どちらにもカウントされていること
    final byDifficulty = stats['byDifficulty']!;
    final byCategory = stats['byCategory']!;
    expect(byDifficulty['一般問題']?['total'], 2);
    expect(byCategory['成人看護学']?['correct'], 1);

    // クリア
    await AnswerHistory.clear();
    final afterClear = await AnswerHistory.all();
    expect(afterClear, isEmpty);
  });
}