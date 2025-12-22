// lib/models/nurai_question.dart
class NuraiQuestion {
  final String questionText;
  final Map<String, String> choices;

  /// 正解ラベル（例: ["3"] / ["2","4"] / 入力式なら ["3.8"] など）
  final List<String> correctLabels;

  /// 各選択肢の根拠（任意）
  final Map<String, String>? rationales;

  /// 解説（任意）
  final String? explanation;

  /// single / multiple / select_incorrect / input（必要なら）
  final String questionKind;

  /// 複数選択の必要正解数
  final int requiredCorrectCount;

  /// 難易度など（任意）
  final String difficulty;
  final String domain;
  final String major;
  final String? mid;
  final String? topic;

  /// 過去問
  final String sourceType;
  final String? sourceTag;

  /// ★ 画像パス（assets のパス）
  /// 例: assets/fig/111/am_q11_femur.png
  final String? imagePath;

  /// ★ 画像が必要か（任意）
  final bool imageRequired;

  const NuraiQuestion({
    required this.questionText,
    required this.choices,
    required this.correctLabels,
    this.rationales,
    this.explanation,
    this.questionKind = 'single',
    required this.requiredCorrectCount,
    this.difficulty = '',
    this.domain = '',
    this.major = '',
    this.mid,
    this.topic,
    this.sourceType = 'past_exam',
    this.sourceTag,
    this.imagePath,
    this.imageRequired = false,
  });

  /// 複数選択（誤答選択も複数になり得る）
  bool get isMultiple => questionKind == 'multiple' || questionKind == 'select_incorrect';

  /// 入力式（計算問題など）：choices が空でも input とみなす
  bool get isInput => questionKind == 'input' || choices.isEmpty;

  bool get hasImage => (imagePath ?? '').trim().isNotEmpty;
}