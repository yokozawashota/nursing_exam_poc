// lib/models/history_models.dart

/// 1問ぶんの履歴を表すモデル。
/// 既存の保存形式に合わせて Map との相互変換も用意しています。
class HistoryRecord {
  final DateTime timestamp;   // 解答時刻
  final String difficulty;    // '必修問題' / '一般問題' / '状況設定問題'
  final String domain;        // 分野
  final String major;         // 大項目
  final String? mid;          // 中項目（任意）
  final String? topic;        // トピック（任意）
  final bool correct;         // 正解なら true
  final int? elapsedMs;       // 解答に要した時間（ミリ秒／任意）

  const HistoryRecord({
    required this.timestamp,
    required this.difficulty,
    required this.domain,
    required this.major,
    this.mid,
    this.topic,
    required this.correct,
    this.elapsedMs,
  });

  /// Map -> HistoryRecord（ストレージや既存JSONからの復元用）
  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    final ts = map['timestamp'];
    // ISO8601文字列またはミリ秒UNIXの両対応
    final DateTime t = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();

    return HistoryRecord(
      timestamp: t,
      difficulty: (map['difficulty'] ?? '').toString(),
      domain: (map['domain'] ?? '').toString(),
      major: (map['major'] ?? '').toString(),
      mid: map['mid']?.toString(),
      topic: map['topic']?.toString(),
      correct: (map['correct'] == true) || (map['isCorrect'] == true),
      elapsedMs: map['elapsedMs'] is int ? map['elapsedMs'] as int : null,
    );
  }

  /// HistoryRecord -> Map（保存・共有用）
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'difficulty': difficulty,
      'domain': domain,
      'major': major,
      if (mid != null) 'mid': mid,
      if (topic != null) 'topic': topic,
      'correct': correct,
      if (elapsedMs != null) 'elapsedMs': elapsedMs,
    };
  }
}

/// 日別要約（チャートに載せやすい形）
class DailySummary {
  final DateTime date; // 時刻は 00:00 固定
  final int total;
  final int correct;
  double get accuracy => total == 0 ? 0 : correct / total;

  const DailySummary({
    required this.date,
    required this.total,
    required this.correct,
  });
}

/// ドメイン別要約
class DomainSummary {
  final String domain;
  final int total;
  final int correct;
  double get accuracy => total == 0 ? 0 : correct / total;

  const DomainSummary({
    required this.domain,
    required this.total,
    required this.correct,
  });
}

/// ローリング（移動平均）精度の一点
class RollingPoint {
  final DateTime date;
  final double accuracy; // 0..1
  const RollingPoint({required this.date, required this.accuracy});
}

/// 連続正解/不正解の情報
class Streaks {
  final int currentCorrect; // 直近の連続正解数
  final int bestCorrect;    // 過去最大の連続正解数
  final int currentWrong;   // 直近の連続不正解数
  final int bestWrong;      // 過去最大の連続不正解数

  const Streaks({
    required this.currentCorrect,
    required this.bestCorrect,
    required this.currentWrong,
    required this.bestWrong,
  });
}