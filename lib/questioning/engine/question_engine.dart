// lib/questioning/engine/question_engine.dart
//
// ★ 共通入口：practice/mock_exam からは原則ここだけを呼ぶ（パターンA）
// - UI を変えずに QuestionService 直呼びを隠す
// - まずは戻り値を Map のままにして既存UIを壊さない
// - 将来（パターンB）で QuestionService を分割し、GeneratedQuestion を返すように進化させる

import '../models/question_spec.dart';
import '../services/question_service.dart';

class QuestionEngine {
  QuestionEngine._();
  static final QuestionEngine instance = QuestionEngine._();

  /// 既存 UI の互換性のため Map を返す。
  /// 将来は GeneratedQuestion を返す方向へ（パターンB）。
  Future<Map<String, dynamic>> generate(QuestionSpec spec) async {
    return QuestionService.fetchQuestion(
      difficulty: spec.difficulty,
      domain: spec.domain,
      major: spec.major,
      mid: spec.mid,
      scenarioAspect: spec.scenarioAspectCode,
    );
  }
}