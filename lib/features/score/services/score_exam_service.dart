// lib/features/score/services/score_exam_service.dart

import '../../history/services/history_answer_service.dart';

/// 国試の大きな区分
///
/// - 必修
/// - 一般
/// - 状況設定
enum ExamSection {
  hisshu,
  ippan,
  jokyo,
}

/// 国試スコアの集計結果
class ExamScore {
  final int answeredHisshu;
  final int correctHisshu;

  /// 一般 + 状況設定 をまとめた数
  final int answeredGeneralLike;
  final int correctGeneralLike;

  /// 必修正答率 (0.0〜1.0)
  final double hisshuRate;

  /// 一般＋状況設定 正答率 (0.0〜1.0)
  final double generalRate;

  /// 必修スコア（0〜50点にスケーリング）
  final double hisshuScore;

  /// 一般+状況設定スコア（0〜350点にスケーリング）
  final double generalScore;

  /// 必修合格ライン（8割以上）
  final bool isPassHisshu;

  /// 一般+状況 合格ライン（6割以上想定）
  final bool isPassGeneral;

  /// データが「そこそこ十分にある」と言えるかの目安
  final bool hasEnoughData;

  const ExamScore({
    required this.answeredHisshu,
    required this.correctHisshu,
    required this.answeredGeneralLike,
    required this.correctGeneralLike,
    required this.hisshuRate,
    required this.generalRate,
    required this.hisshuScore,
    required this.generalScore,
    required this.isPassHisshu,
    required this.isPassGeneral,
    required this.hasEnoughData,
  });

  /// 合計スコア（0〜400点）
  double get totalScore => hisshuScore + generalScore;

  /// 両方クリアしているか
  bool get isPass => isPassHisshu && isPassGeneral;
}

/// 国試スコア計算サービス
class ExamScoreService {
  ExamScoreService._();

  /// AnswerRecord から difficulty を見て区分を推定する
  static ExamSection? sectionOfRecord(AnswerRecord record) {
    final difficulty = record.difficulty.trim();

    if (difficulty.contains('必修')) {
      return ExamSection.hisshu;
    }
    if (difficulty.contains('状況')) {
      return ExamSection.jokyo;
    }
    if (difficulty.contains('一般')) {
      return ExamSection.ippan;
    }

    return null;
  }

  /// 解答履歴一覧から国試スコアを集計する
  ///
  /// スコアの考え方:
  /// - 必修：正答率 × 50点
  /// - 一般+状況：正答率 × 350点
  ///
  /// つまり
  /// 「今の正答率のまま本番を解いたと仮定したときの目安スコア」
  /// を返す。
  static ExamScore calculate(List<AnswerRecord> records) {
    int answeredHisshu = 0;
    int correctHisshu = 0;

    int answeredGeneralLike = 0;
    int correctGeneralLike = 0;

    for (final record in records) {
      final section = sectionOfRecord(record);
      if (section == null) continue;

      switch (section) {
        case ExamSection.hisshu:
          answeredHisshu++;
          if (record.isCorrect) {
            correctHisshu++;
          }
          break;

        case ExamSection.ippan:
        case ExamSection.jokyo:
          answeredGeneralLike++;
          if (record.isCorrect) {
            correctGeneralLike++;
          }
          break;
      }
    }

    final hisshuRate = _rate(correctHisshu, answeredHisshu);
    final generalRate = _rate(correctGeneralLike, answeredGeneralLike);

    final hisshuScore = hisshuRate * 50.0;
    final generalScore = generalRate * 350.0;

    final isPassHisshu = hisshuRate >= 0.8;
    final isPassGeneral = generalRate >= 0.6;

    final hasEnoughData =
        answeredHisshu >= 10 && answeredGeneralLike >= 30;

    return ExamScore(
      answeredHisshu: answeredHisshu,
      correctHisshu: correctHisshu,
      answeredGeneralLike: answeredGeneralLike,
      correctGeneralLike: correctGeneralLike,
      hisshuRate: hisshuRate,
      generalRate: generalRate,
      hisshuScore: hisshuScore,
      generalScore: generalScore,
      isPassHisshu: isPassHisshu,
      isPassGeneral: isPassGeneral,
      hasEnoughData: hasEnoughData,
    );
  }

  static double _rate(int correct, int total) {
    if (total == 0) {
      return 0.0;
    }
    return correct / total;
  }
}