// lib/features/mock_exam/models/mock_exam_state.dart
class MockExamState {
  bool isLoading = false;

  String? questionText;
  Map<String, String>? choices;
  List<String>? correctAnswers;
  String? explanation;
  Map<String, String>? rationales;
  Set<String> userAnswers = {};
  String questionKind = 'single';

  String? currentDifficulty;
  String? currentDomain;
  String? currentMajor;
  String? currentMid;
  String? currentTopic;
  Map<String, dynamic>? meta;

  void clearQuestion() {
    questionText = null;
    choices = null;
    correctAnswers = null;
    explanation = null;
    rationales = null;
    userAnswers = {};
    questionKind = 'single';
    meta = null;
    currentDifficulty = null;
    currentDomain = null;
    currentMajor = null;
    currentMid = null;
    currentTopic = null;
  }
}