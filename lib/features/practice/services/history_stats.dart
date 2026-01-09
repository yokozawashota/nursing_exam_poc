// lib/features/practice/services/history_stats.dart
import 'package:collection/collection.dart';
import '../../../shared/models/history_models.dart';

/// 履歴（HistoryRecordのリスト）から、グラフに必要な統計値を計算する純ロジック。
/// UIやストレージから独立しているため、テストもしやすい構成です。
class HistoryStats {
  /// 日別要約（accuracyは DailySummary.accuracy で参照）
  static List<DailySummary> dailySummaries(List<HistoryRecord> all) {
    if (all.isEmpty) return const [];

    // 日付キー（ローカル日付の 00:00）でグルーピング
    final groups = groupBy<HistoryRecord, DateTime>(
      all,
          (r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day),
    );

    final out = <DailySummary>[];
    for (final entry in groups.entries) {
      final date = entry.key;
      final records = entry.value;
      final total = records.length;
      final correct = records.where((r) => r.correct).length;
      out.add(DailySummary(date: date, total: total, correct: correct));
    }

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// ドメイン別要約（accuracyは DomainSummary.accuracy で参照）
  static List<DomainSummary> domainSummaries(List<HistoryRecord> all) {
    if (all.isEmpty) return const [];

    final groups = groupBy<HistoryRecord, String>(all, (r) => r.domain);
    final out = <DomainSummary>[];

    for (final entry in groups.entries) {
      final domain = entry.key;
      final records = entry.value;
      final total = records.length;
      final correct = records.where((r) => r.correct).length;
      out.add(DomainSummary(domain: domain, total: total, correct: correct));
    }

    out.sort((a, b) => a.domain.compareTo(b.domain));
    return out;
  }

  /// 移動平均精度（windowDays 日のローリング）
  /// 例：windowDays=7 → 各日について直近7日間の正答率を算出
  static List<RollingPoint> rollingAccuracyByDay(
      List<HistoryRecord> all, {
        int windowDays = 7,
      }) {
    final daily = dailySummaries(all);
    if (daily.isEmpty) return const [];

    final out = <RollingPoint>[];

    for (var i = 0; i < daily.length; i++) {
      final end = daily[i].date;
      final start = end.subtract(Duration(days: windowDays - 1));
      int total = 0;
      int correct = 0;

      for (var j = 0; j <= i; j++) {
        final d = daily[j];
        if (d.date.isBefore(start) || d.date.isAfter(end)) continue;
        total += d.total;
        correct += d.correct;
      }

      final acc = total == 0 ? 0.0 : correct / total;
      out.add(RollingPoint(date: end, accuracy: acc));
    }
    return out;
  }

  /// 直近N問の正答率（質問数ベースの移動窓）
  static double recentAccuracy(List<HistoryRecord> all, {int lastN = 20}) {
    if (all.isEmpty) return 0.0;
    final slice = (all.length <= lastN) ? all : all.sublist(all.length - lastN);
    final total = slice.length;
    final correct = slice.where((r) => r.correct).length;
    return total == 0 ? 0.0 : correct / total;
  }

  /// 正解・不正解の連続記録
  static Streaks streaks(List<HistoryRecord> all) {
    int currentCorrect = 0, bestCorrect = 0;
    int currentWrong = 0, bestWrong = 0;

    for (final r in all) {
      if (r.correct) {
        currentCorrect += 1;
        bestCorrect = currentCorrect > bestCorrect ? currentCorrect : bestCorrect;
        currentWrong = 0;
      } else {
        currentWrong += 1;
        bestWrong = currentWrong > bestWrong ? currentWrong : bestWrong;
        currentCorrect = 0;
      }
    }

    return Streaks(
      currentCorrect: currentCorrect,
      bestCorrect: bestCorrect,
      currentWrong: currentWrong,
      bestWrong: bestWrong,
    );
  }

  /// 指定ドメイン/大項目でフィルタ。UI側のドロップダウンと組み合わせやすい。
  static List<HistoryRecord> filter({
    required List<HistoryRecord> all,
    String? domain,
    String? major,
    String? mid,
  }) {
    return all.where((r) {
      if (domain != null && domain.isNotEmpty && r.domain != domain) return false;
      if (major != null && major.isNotEmpty && r.major != major) return false;
      if (mid != null && mid.isNotEmpty && r.mid != mid) return false;
      return true;
    }).toList();
  }
}