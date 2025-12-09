// lib/ai_analysis/record_structure_enricher.dart

import '../models/answer_history.dart';
import 'classification_service.dart';

/// ----------------------------------------------
/// 解答履歴の構造情報（major / mid / topic）を
/// LLM を使って自動補完するユーティリティ
/// ----------------------------------------------
class RecordStructureEnricher {
  /// 1回の分析で LLM に問い合わせる最大件数
  /// （コスト・時間を抑えるための上限）
  static const int maxEnrichCount = 50;

  /// 与えられた AnswerRecord のリストに対して、
  /// major / mid / topic がすべて空のものだけ LLM で補完して返す。
  ///
  /// すでに値が入っているレコードはそのまま返却する。
  static Future<List<AnswerRecord>> enrichAll(
      List<AnswerRecord> records,
      ) async {
    if (records.isEmpty) return records;

    final List<AnswerRecord> result = [];
    int enrichedCount = 0;

    for (final r in records) {
      if (_needsEnrich(r) && enrichedCount < maxEnrichCount) {
        final enriched = await enrichOne(r);
        result.add(enriched);
        enrichedCount++;
      } else {
        result.add(r);
      }
    }

    return result;
  }

  /// 単一レコードについて、major / mid / topic を補完した
  /// 新しい AnswerRecord を返す。
  ///
  /// すでにいずれかが埋まっている場合は、そのまま返す。
  static Future<AnswerRecord> enrichOne(AnswerRecord record) async {
    if (!_needsEnrich(record)) {
      return record;
    }

    // LLM で major / mid / topic を推定
    final classified = await ClassificationService.classifyStructure(
      question: record.question,
      difficulty: record.difficulty,
    );

    final major = _normalize(classified['major']);
    final mid = _normalize(classified['mid']);
    final topic = _normalize(classified['topic']);

    return record.copyWith(
      major: major,
      mid: mid,
      topic: topic,
    );
  }

  /// major / mid / topic がすべて空かどうか判定
  static bool _needsEnrich(AnswerRecord r) {
    return _isNullOrEmpty(r.major) &&
        _isNullOrEmpty(r.mid) &&
        _isNullOrEmpty(r.topic);
  }

  static bool _isNullOrEmpty(String? v) {
    if (v == null) return true;
    return v.trim().isEmpty;
  }

  /// LLM から返ってきた文字列を軽く正規化
  static String _normalize(String? v) {
    if (v == null) return '未分類';
    final trimmed = v.trim();
    if (trimmed.isEmpty) return '未分類';
    return trimmed;
  }
}