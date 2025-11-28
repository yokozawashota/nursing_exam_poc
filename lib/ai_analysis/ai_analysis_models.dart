// lib/ai_analysis/ai_analysis_models.dart
import 'package:flutter/foundation.dart';

/// AI分析の口調
enum AnalysisTone {
  gentle,   // やさしい
  neutral,  // 標準
  strict,   // やや厳しめ
  coach,    // 熱血コーチ
  clinical, // 医療従事者向け・専門的
}

extension AnalysisToneExt on AnalysisTone {
  String get id {
    switch (this) {
      case AnalysisTone.gentle:
        return 'gentle';
      case AnalysisTone.neutral:
        return 'neutral';
      case AnalysisTone.strict:
        return 'strict';
      case AnalysisTone.coach:
        return 'coach';
      case AnalysisTone.clinical:
        return 'clinical';
    }
  }

  String get label {
    switch (this) {
      case AnalysisTone.gentle:
        return 'やさしい';
      case AnalysisTone.neutral:
        return '標準';
      case AnalysisTone.strict:
        return 'やや厳しめ';
      case AnalysisTone.coach:
        return '熱血コーチ風';
      case AnalysisTone.clinical:
        return '専門家コメント風';
    }
  }

  String get description {
    switch (this) {
      case AnalysisTone.gentle:
        return '励まし多めで、メンタルにやさしいコメントを行います。';
      case AnalysisTone.neutral:
        return 'フラットで落ち着いたトーンで、事実ベースにコメントします。';
      case AnalysisTone.strict:
        return 'やや厳しめに課題を指摘し、改善ポイントをはっきり伝えます。';
      case AnalysisTone.coach:
        return '熱血指導風に、前向きなエネルギー強めでコメントします。';
      case AnalysisTone.clinical:
        return '医療従事者向けの、やや専門的で臨床寄りのコメントを行います。';
    }
  }

  static AnalysisTone fromId(String id) {
    switch (id) {
      case 'gentle':
        return AnalysisTone.gentle;
      case 'neutral':
        return AnalysisTone.neutral;
      case 'strict':
        return AnalysisTone.strict;
      case 'coach':
        return AnalysisTone.coach;
      case 'clinical':
        return AnalysisTone.clinical;
      default:
        return AnalysisTone.neutral;
    }
  }
}

/// 出題形式の統計
class DifficultyStat {
  final String name;
  final int total;
  final int correct;

  const DifficultyStat({
    required this.name,
    required this.total,
    required this.correct,
  });

  double get rate => total == 0 ? 0.0 : correct / total;
}

/// 分野の統計
class DomainStat {
  final String name;
  final int total;
  final int correct;

  const DomainStat({
    required this.name,
    required this.total,
    required this.correct,
  });

  double get rate => total == 0 ? 0.0 : correct / total;
}

/// AI分析の結果モデル
class AiAnalysisResult {
  final int totalAnswers;
  final double overallAccuracy;

  final String introMessage;
  final String difficultyComment;
  final String domainComment;
  final String studyAdvice;
  final String nuraiComment;

  final List<DifficultyStat> difficultyStats;
  final List<DomainStat> domainStats;

  const AiAnalysisResult({
    required this.totalAnswers,
    required this.overallAccuracy,
    required this.introMessage,
    required this.difficultyComment,
    required this.domainComment,
    required this.studyAdvice,
    required this.nuraiComment,
    this.difficultyStats = const <DifficultyStat>[],
    this.domainStats = const <DomainStat>[],
  });
}