// lib/features/past_exam/models/past_exam_question.dart

class NuraiQuestion {
  final String questionText;

  /// 状況設定などの「背景文」（任意）
  /// JSON側で backgroundText / background / context / scenario / scenarioText があれば読み取る
  final String? backgroundText;

  /// 'A' -> '...' / '1' -> '...'
  final Map<String, String> choices;

  /// ['A'] or ['A','C']
  final List<String> correctLabels;

  /// 選択肢ごとの根拠（過去問JSONの choiceRationales）
  final Map<String, String>? choiceRationales;

  final String? explanation;

  /// 'single' / 'multi' / 'select_incorrect' etc
  final String questionKind;

  final int requiredCorrectCount;

  final String difficulty;
  final String domain;
  final String major;
  final String? mid;
  final String? topic;

  /// 'llm' / 'past_exam'
  final String sourceType;

  /// unique key
  final String sourceTag;

  final String? imagePath;
  final bool imageRequired;

  const NuraiQuestion({
    required this.questionText,
    this.backgroundText,
    required this.choices,
    required this.correctLabels,
    this.choiceRationales,
    this.explanation,
    required this.questionKind,
    required this.requiredCorrectCount,
    required this.difficulty,
    required this.domain,
    required this.major,
    this.mid,
    this.topic,
    required this.sourceType,
    required this.sourceTag,
    this.imagePath,
    required this.imageRequired,
  });

  NuraiQuestion copyWith({
    String? questionText,
    String? backgroundText,
    Map<String, String>? choices,
    List<String>? correctLabels,
    Map<String, String>? choiceRationales,
    String? explanation,
    String? questionKind,
    int? requiredCorrectCount,
    String? difficulty,
    String? domain,
    String? major,
    String? mid,
    String? topic,
    String? sourceType,
    String? sourceTag,
    String? imagePath,
    bool? imageRequired,
  }) {
    return NuraiQuestion(
      questionText: questionText ?? this.questionText,
      backgroundText: backgroundText ?? this.backgroundText,
      choices: choices ?? this.choices,
      correctLabels: correctLabels ?? this.correctLabels,
      choiceRationales: choiceRationales ?? this.choiceRationales,
      explanation: explanation ?? this.explanation,
      questionKind: questionKind ?? this.questionKind,
      requiredCorrectCount: requiredCorrectCount ?? this.requiredCorrectCount,
      difficulty: difficulty ?? this.difficulty,
      domain: domain ?? this.domain,
      major: major ?? this.major,
      mid: mid ?? this.mid,
      topic: topic ?? this.topic,
      sourceType: sourceType ?? this.sourceType,
      sourceTag: sourceTag ?? this.sourceTag,
      imagePath: imagePath ?? this.imagePath,
      imageRequired: imageRequired ?? this.imageRequired,
    );
  }
}