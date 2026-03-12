// lib/features/mock_exam/models/mock_exam_result_data.dart

import '../../history/services/history_answer_service.dart';

/// 模試終了後の結果データをまとめたモデル。
/// Controller → Screen に渡すためのデータコンテナ。
class MockExamResultData {
  /// 回答履歴
  final List<AnswerRecord> records;

  /// 計画された総問題数
  final int totalPlanned;

  /// 実際に回答した問題数
  final int answeredCount;

  /// 正解数
  final int correctCount;

  /// 使用時間（秒）
  final int usedSeconds;

  /// 制限時間（秒）
  final int timeLimitSeconds;

  /// 制限時間による終了か
  final bool finishedByTimeout;

  const MockExamResultData({
    required this.records,
    required this.totalPlanned,
    required this.answeredCount,
    required this.correctCount,
    required this.usedSeconds,
    required this.timeLimitSeconds,
    required this.finishedByTimeout,
  });
}