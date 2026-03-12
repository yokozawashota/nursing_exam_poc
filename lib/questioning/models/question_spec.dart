// lib/questioning/models/question_spec.dart
//
// 出題生成リクエスト（DTO）
// ※ Ver5 移行フェーズ（パターンA）では、まず UI から QuestionService を隠すための最小DTO。
// ※ choiceMode/確率/4択5択/複数選択などは SettingsService と QuestionService 側で決定する方針のため、ここでは持たない。

class QuestionSpec {
  final String difficulty;
  final String domain;
  final String major;
  final String? mid;

  /// 状況設定の観点コード（例: 'jokyo_XXXX' など）
  /// practice/mock_exam 共通で “code” を渡す想定のためこの名前に統一。
  final String? scenarioAspectCode;

  const QuestionSpec({
    required this.difficulty,
    required this.domain,
    required this.major,
    this.mid,
    this.scenarioAspectCode,
  });

  @override
  String toString() {
    return 'QuestionSpec(difficulty=$difficulty, domain=$domain, major=$major, mid=$mid, scenarioAspectCode=$scenarioAspectCode)';
  }
}