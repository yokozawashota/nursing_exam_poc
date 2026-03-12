// lib/questioning/models/generated_question.dart

/// GeneratedQuestion
///
/// LLM によって生成された問題データを、型安全に扱うための
/// DTO（Data Transfer Object / データ受け渡し用オブジェクト）。
///
/// 現在の NurAI では、practice / mock_exam / 一部互換処理との整合のため、
/// QuestionService の主な返り値はまだ `Map<String, dynamic>` を使用している。
/// そのため、このクラスは現時点では
/// 「将来のDTO本線化に向けた準備用モデル」という位置づけである。
///
/// 想定している将来構造は以下のとおり。
///
/// ResponseParser
///   ↓
/// GeneratedQuestion
///   ↓
/// QuestionService / QuestionEngine
///   ↓
/// practice / mock_exam / その他UI層
///
/// DTO化により期待できること:
/// - 型安全性の向上
/// - IDE補完の強化
/// - 保守性の向上
/// - 問題データ構造の明確化
///
/// ただし現段階では、UI層や既存互換処理が Map ベースで動作しているため、
/// 全面移行はまだ行っていない。
///
/// そのためこのクラスは、今後のリファクタリング時に
/// questioning 内部から段階的に DTO 化を進めるための基盤として保持する。
class GeneratedQuestion {
  final String question;
  final Map<String, String> choices;
  final List<String> correctAnswers;
  final String questionKind;
  final String explanation;
  final Map<String, String>? rationales;
  final String sourceType;

  const GeneratedQuestion({
    required this.question,
    required this.choices,
    required this.correctAnswers,
    required this.questionKind,
    required this.explanation,
    this.rationales,
    required this.sourceType,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'choices': choices,
    'correctAnswers': correctAnswers,
    'questionKind': questionKind,
    'explanation': explanation,
    'rationales': rationales,
    'sourceType': sourceType,
  };
}