import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 1件分の解答記録（UIは変更せず内部だけ拡張）
class AnswerRecord {
  /// 解答日時（内部表現は at に統一）
  final DateTime at;

  /// 分野（例：成人看護学 など。必修の場合は '必修' 推奨）
  final String category;

  /// 出題形式：必修 / 一般 / 状況設定（保存名は form に統一）
  final String form;

  /// 正誤
  final bool correct;

  /// 任意のID
  final int? questionId;

  /// 備考（問題タイトルなど、任意）
  final String? note;

  // ====== 履歴詳細用のスナップショット ======
  /// 当時の問題文
  final String? questionText;

  /// 当時の選択肢
  final List<String>? choices;

  /// ユーザーが選んだ選択肢のインデックス（0-origin）
  final int? selectedIndex;

  /// 正解の選択肢インデックス（0-origin）
  final int? correctIndex;

  /// 当時の解説
  final String? explanation;

  /// 後方互換コンストラクタ
  ///
  /// - `at` … 推奨フィールド
  /// - `date` … 旧実装エイリアス（指定があれば at へ吸収）
  /// - `form` … 出題形式（必修/一般/状況設定）
  /// - `difficulty` … 旧実装エイリアス（指定があれば form へ吸収）
  AnswerRecord({
    DateTime? at,
    DateTime? date,
    required this.category,
    required this.correct,
    String? form,
    String? difficulty,
    this.questionId,
    this.note,
    this.questionText,
    this.choices,
    this.selectedIndex,
    this.correctIndex,
    this.explanation,
  })  : at = (at ?? date ?? DateTime.now()),
        form = (form ?? difficulty ?? '未指定');

  factory AnswerRecord.fromJson(Map<String, dynamic> j) {
    DateTime parseAt(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.parse(v);
      return DateTime.now();
    }

    List<String>? parseChoices(dynamic v) {
      if (v == null) return null;
      if (v is List) {
        return v.map((e) => e?.toString() ?? '').toList();
      }
      return null;
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final at = parseAt(j['at'] ?? j['date']);
    final form = (j['form'] ?? j['difficulty'] ?? '未指定').toString();

    return AnswerRecord(
      at: at,
      category: (j['category'] ?? '未指定').toString(),
      correct: (j['correct'] as bool?) ?? false,
      form: form,
      questionId: parseInt(j['questionId']),
      note: (j['note'] as String?),
      questionText: (j['questionText'] as String?),
      choices: parseChoices(j['choices']),
      selectedIndex: parseInt(j['selectedIndex']),
      correctIndex: parseInt(j['correctIndex']),
      explanation: (j['explanation'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'category': category,
    'form': form,
    'correct': correct,
    'questionId': questionId,
    'note': note,
    // スナップショット
    'questionText': questionText,
    'choices': choices,
    'selectedIndex': selectedIndex,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}

/// 履歴の保存・集計ヘルパ
class AnswerHistory {
  static const _storageKey = 'answer_history_v1';

  /// 全取得（存在しない/空でも []）
  static Future<List<AnswerRecord>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List data = jsonDecode(raw) as List;
      return data
          .map((e) => AnswerRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 破損などは安全に初期化
      return [];
    }
  }

  /// 全件置き換え保存
  static Future<void> _saveAll(List<AnswerRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  /// 1件追加（最大件数制限が必要なら keepLatest でカットオフ）
  static Future<void> add(AnswerRecord record, {int? keepLatest}) async {
    final items = await all();
    items.add(record);
    if (keepLatest != null && keepLatest > 0 && items.length > keepLatest) {
      final start = items.length - keepLatest;
      final trimmed = items.sublist(start);
      await _saveAll(trimmed);
      return;
    }
    await _saveAll(items);
  }

  /// “当時のスナップショット” を保存するユーティリティ
  static Future<void> addSnapshot({
    DateTime? at,
    required String category,
    required String form, // 必修 / 一般 / 状況設定
    required bool correct,
    int? questionId,
    String? note,
    required String questionText,
    required List<String> choices,
    required int selectedIndex,
    required int correctIndex,
    String? explanation,
    int? keepLatest,
  }) {
    return add(
      AnswerRecord(
        at: at,
        category: category,
        form: form,
        correct: correct,
        questionId: questionId,
        note: note,
        questionText: questionText,
        choices: choices,
        selectedIndex: selectedIndex,
        correctIndex: correctIndex,
        explanation: explanation,
      ),
      keepLatest: keepLatest,
    );
  }

  /// 全削除
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// 形式・分野ごとの集計を含むサマリー（UI向け）
  static Future<HistorySummary> summary() async {
    final items = await all();
    final total = items.length;
    final correct = items.where((e) => e.correct).length;
    final accuracy = total == 0 ? 0.0 : correct / total;

    // 分野別
    final byCategory = <String, _Count>{};
    for (final r in items) {
      final c = byCategory.putIfAbsent(r.category, () => _Count());
      c.total++;
      if (r.correct) c.correct++;
    }

    // 出題形式別（必修 / 一般 / 状況設定 など）
    final byForm = <String, _Count>{};
    for (final r in items) {
      final c = byForm.putIfAbsent(r.form, () => _Count());
      c.total++;
      if (r.correct) c.correct++;
    }

    return HistorySummary(
      total: total,
      correct: correct,
      accuracy: accuracy,
      byCategory: byCategory.map(
            (k, v) => MapEntry(k, CategoryStat(total: v.total, correct: v.correct)),
      ),
      byForm: byForm.map(
            (k, v) => MapEntry(k, CategoryStat(total: v.total, correct: v.correct)),
      ),
    );
  }

  /// 旧テスト互換：Map 形式で返す統計
  static Future<Map<String, dynamic>> calculateStats() async {
    final s = await summary();

    Map<String, dynamic> encodeStatsMap(Map<String, CategoryStat> src) {
      return src.map((k, v) => MapEntry(k, {
        'total': v.total,
        'correct': v.correct,
        'accuracy': v.accuracy,
      }));
    }

    return {
      'overall': {
        'total': s.total,
        'correct': s.correct,
        'accuracy': s.accuracy,
      },
      'byDifficulty': encodeStatsMap(s.byForm),
      'byCategory': encodeStatsMap(s.byCategory),
    };
  }
}

class _Count {
  int total = 0;
  int correct = 0;
}

/// 画面で使うサマリー（UIコードから参照）
class HistorySummary {
  final int total;
  final int correct;
  final double accuracy; // 0.0..1.0
  final Map<String, CategoryStat> byCategory;
  final Map<String, CategoryStat> byForm;

  const HistorySummary({
    required this.total,
    required this.correct,
    required this.accuracy,
    required this.byCategory,
    required this.byForm,
  });
}

class CategoryStat {
  final int total;
  final int correct;

  const CategoryStat({required this.total, required this.correct});

  double get accuracy => total == 0 ? 0.0 : correct / total;
}