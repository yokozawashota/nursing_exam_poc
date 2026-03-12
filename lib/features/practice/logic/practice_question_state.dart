// lib/features/practice/logic/practice_question_state.dart

class PracticeQuestionState {
  // ==========================
  // 画面状態
  // ==========================
  bool isLoading = false;

  // ==========================
  // 出題設定
  // ==========================
  String mode = '必修問題';

  String selectedDomain = '';
  String selectedMajor = '';
  String? selectedMid;

  String selectedHisshuMajor = '';

  String? selectedScenarioAspectCode;

  bool useMid = false;

  // ==========================
  // 出題中データ
  // ==========================
  String? questionText;

  Map<String, String>? choices;

  List<String>? correctAnswers;

  String? explanation;

  Map<String, String>? rationales;

  String questionKind = 'single';

  Set<String> userAnswers = {};

  // ==========================
  // 履歴保存用メタ
  // ==========================
  Map<String, dynamic>? meta;

  // ==========================
  // Loading UI
  // ==========================
  int loadingMessageIndex = 0;

  double loadingProgress = 0.0;

  // ==========================
  // ユーティリティ
  // ==========================
  void clearQuestion() {
    questionText = null;
    choices = null;
    correctAnswers = null;
    explanation = null;
    rationales = null;
    userAnswers = {};
    questionKind = 'single';
    meta = null;
  }
}