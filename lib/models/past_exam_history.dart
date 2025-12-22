// lib/models/past_exam_history.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 過去問の解答1件（スナップショット込み）
///
/// 画面側が参照する可能性があるフィールド/Getterは「ここに集約」して固定する。
class PastExamAnswerRecord {
  // 識別
  final String examId; // '111' など
  final String questionKey; // ユニーク（例: '第111回 一般問題 午前 1問'）
  final bool isCorrect;

  // 表示用メタ
  final String? examTitle; // '第111回（2022年）'
  final String? partLabel; // '一般問題 午前'
  final String? partKind; // '必修' / '一般' / '状況設定'
  final int? questionNo; // 1,2,3...

  // スナップショット
  final String? questionText;
  final Map<String, String>? choices;
  final List<String>? correctLabels;
  final List<String>? selectedLabels;
  final String? explanation;
  final Map<String, String>? rationales;

  // 画像
  final String? imagePath;

  // 回答日時（ms）
  final int answeredAtMs;

  const PastExamAnswerRecord({
    required this.examId,
    required this.questionKey,
    required this.isCorrect,
    required this.answeredAtMs,
    this.examTitle,
    this.partLabel,
    this.partKind,
    this.questionNo,
    this.questionText,
    this.choices,
    this.correctLabels,
    this.selectedLabels,
    this.explanation,
    this.rationales,
    this.imagePath,
  });

  /// 互換：画面が昔 `ts` を参照していた
  DateTime get ts => DateTime.fromMillisecondsSinceEpoch(answeredAtMs);

  /// 互換：画面が `hasSnapshot` を参照していた
  bool get hasSnapshot => (questionText ?? '').trim().isNotEmpty;

  /// 互換：画面が `hasImage` を参照していた
  bool get hasImage => (imagePath ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'examId': examId,
      'questionKey': questionKey,
      'isCorrect': isCorrect,
      'answeredAtMs': answeredAtMs,
      'examTitle': examTitle,
      'partLabel': partLabel,
      'partKind': partKind,
      'questionNo': questionNo,
      'questionText': questionText,
      'choices': choices,
      'correctLabels': correctLabels,
      'selectedLabels': selectedLabels,
      'explanation': explanation,
      'rationales': rationales,
      'imagePath': imagePath,
    };
  }

  static PastExamAnswerRecord fromJson(Map<String, dynamic> j) {
    Map<String, String>? mapSS(dynamic v) {
      if (v == null) return null;
      final m = Map<String, dynamic>.from(v as Map);
      return m.map((k, vv) => MapEntry(k.toString(), (vv ?? '').toString()));
    }

    List<String>? listS(dynamic v) {
      if (v == null) return null;
      return (v as List).map((e) => (e ?? '').toString()).toList();
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return PastExamAnswerRecord(
      examId: (j['examId'] ?? '').toString(),
      questionKey: (j['questionKey'] ?? '').toString(),
      isCorrect: (j['isCorrect'] ?? false) as bool,
      answeredAtMs: (j['answeredAtMs'] ?? 0) as int,
      examTitle: j['examTitle']?.toString(),
      partLabel: j['partLabel']?.toString(),
      partKind: j['partKind']?.toString(),
      questionNo: parseInt(j['questionNo']),
      questionText: j['questionText']?.toString(),
      choices: mapSS(j['choices']),
      correctLabels: listS(j['correctLabels']),
      selectedLabels: listS(j['selectedLabels']),
      explanation: j['explanation']?.toString(),
      rationales: mapSS(j['rationales']),
      imagePath: j['imagePath']?.toString(),
    );
  }
}

/// 年度集計（ solved / correct だけを安定提供）
class PastExamYearSummary {
  final int solved;
  final int correct;

  const PastExamYearSummary({required this.solved, required this.correct});

  double get accuracy => solved == 0 ? 0.0 : correct / solved;
}

/// 過去問解答履歴ストア（SharedPreferences）
///
/// ✅ 画面が壊れないように「APIを固定」
/// - versionListenable
/// - all()
/// - recordsForExam(examId)
/// - solvedCountMap(examIds)
/// - summaryMap(examIds)
/// - resetExam(examId)
/// - clearAll()
/// - upsertAnswerWithSnapshot(...)
class PastExamHistory {
  PastExamHistory._();
  static final PastExamHistory instance = PastExamHistory._();

  static const _prefsKey = 'past_exam_history_v4';

  final ValueNotifier<int> _version = ValueNotifier<int>(0);
  ValueListenable<int> get versionListenable => _version;

  bool _loaded = false;

  /// 内部は「ユニークキー -> Record」
  /// ユニークキーは `examId::questionKey`
  final Map<String, PastExamAnswerRecord> _map = {};

  String _k(String examId, String questionKey) => '$examId::$questionKey';

  void _bump() => _version.value = _version.value + 1;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);

      // v4: Map<String, dynamic>（key -> recordJson）
      if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        for (final e in m.entries) {
          final v = e.value;
          if (v is Map) {
            final rec = PastExamAnswerRecord.fromJson(
              Map<String, dynamic>.from(v),
            );
            _map[_k(rec.examId, rec.questionKey)] = rec;
          }
        }
        return;
      }

      // 旧: List（recordJson の配列）
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final rec = PastExamAnswerRecord.fromJson(
              Map<String, dynamic>.from(item),
            );
            _map[_k(rec.examId, rec.questionKey)] = rec;
          }
        }
      }
    } catch (_) {
      // 壊れたJSONは無視（クラッシュ回避）
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final e in _map.entries) {
      data[e.key] = e.value.toJson();
    }
    await prefs.setString(_prefsKey, jsonEncode(data));
  }

  /// 全件（新しい順）
  Future<List<PastExamAnswerRecord>> all() async {
    await _ensureLoaded();
    final list = _map.values.toList()
      ..sort((a, b) => b.answeredAtMs.compareTo(a.answeredAtMs));
    return list;
  }

  /// 年度（examId）だけ（新しい順）
  Future<List<PastExamAnswerRecord>> recordsForExam(String examId) async {
    await _ensureLoaded();
    final list = _map.values.where((r) => r.examId == examId).toList()
      ..sort((a, b) => b.answeredAtMs.compareTo(a.answeredAtMs));
    return list;
  }

  /// 年度ごとの「解答済み数」
  Future<Map<String, int>> solvedCountMap(List<String> examIds) async {
    await _ensureLoaded();
    final out = <String, int>{for (final id in examIds) id: 0};

    for (final r in _map.values) {
      if (out.containsKey(r.examId)) {
        out[r.examId] = (out[r.examId] ?? 0) + 1;
      }
    }
    return out;
  }

  /// 年度ごとの solved/correct 集計
  Future<Map<String, PastExamYearSummary>> summaryMap(List<String> examIds) async {
    await _ensureLoaded();
    final solved = <String, int>{for (final id in examIds) id: 0};
    final correct = <String, int>{for (final id in examIds) id: 0};

    for (final r in _map.values) {
      if (!solved.containsKey(r.examId)) continue;
      solved[r.examId] = (solved[r.examId] ?? 0) + 1;
      if (r.isCorrect) {
        correct[r.examId] = (correct[r.examId] ?? 0) + 1;
      }
    }

    final out = <String, PastExamYearSummary>{};
    for (final id in examIds) {
      out[id] = PastExamYearSummary(
        solved: solved[id] ?? 0,
        correct: correct[id] ?? 0,
      );
    }
    return out;
  }

  /// 1問ぶんを保存（既存があれば上書き）
  ///
  /// ★ 画面側の変更で壊れないよう、ここは引数を安定させる
  Future<void> upsertAnswerWithSnapshot({
    required String examId,
    required String questionKey,
    required bool isCorrect,

    /// 互換：古い実装が answeredAt を必須にしていたケースがあるので optional
    DateTime? answeredAt,

    // 表示用
    String? examTitle,
    String? partLabel,
    String? partKind,
    int? questionNo,

    // snapshot
    String? questionText,
    Map<String, String>? choices,
    List<String>? correctLabels,
    List<String>? selectedLabels,
    String? explanation,
    Map<String, String>? rationales,

    // image
    String? imagePath,
  }) async {
    await _ensureLoaded();

    final now = answeredAt ?? DateTime.now();
    final rec = PastExamAnswerRecord(
      examId: examId,
      questionKey: questionKey,
      isCorrect: isCorrect,
      answeredAtMs: now.millisecondsSinceEpoch,
      examTitle: examTitle,
      partLabel: partLabel,
      partKind: partKind,
      questionNo: questionNo,
      questionText: questionText,
      choices: choices,
      correctLabels: correctLabels,
      selectedLabels: selectedLabels,
      explanation: explanation,
      rationales: rationales,
      imagePath: imagePath,
    );

    _map[_k(examId, questionKey)] = rec;
    await _save();
    _bump();
  }

  /// 年度ごとにリセット（examId）
  Future<void> resetExam(String examId) async {
    await _ensureLoaded();
    final keys = _map.keys.where((k) => k.startsWith('$examId::')).toList();
    for (final k in keys) {
      _map.remove(k);
    }
    await _save();
    _bump();
  }

  /// 全消し
  Future<void> clearAll() async {
    await _ensureLoaded();
    _map.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _bump();
  }
}