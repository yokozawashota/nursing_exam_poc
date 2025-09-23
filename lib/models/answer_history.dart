// lib/models/answer_history.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 解答履歴 1件分（スナップショット保存型）
/// Phase0/1/2 の拡張に対応：
/// - 可変択数 `choiceCount`
/// - 設問タイプ `questionKind` ('single' / 'multiple' / 'select_incorrect')
/// - 複数解答 `userAnswers` / 複数正答 `correctAnswers`
/// 後方互換：旧データ（単一解答）も自動で配列化して読み込みます。
class AnswerRecord {
  final String id;                // 例: epoch_ms 文字列
  final DateTime ts;              // タイムスタンプ
  final String difficulty;        // '必修問題' / '一般問題' / '状況設定問題'
  final String? domain;           // 分野
  final String? major;            // 大項目
  final String? mid;              // 中項目
  final String? topic;            // 小項目（内部選定）

  // スナップショット（本文）
  final String question;
  final Map<String, String> choices;     // 'A'.. : '本文'
  final String? explanation;             // 解説
  final Map<String, String>? rationales; // 可能なら

  // --- Phase 拡張 ---
  final int choiceCount;                 // 4/5...（未指定時は choices.length を採用）
  final String questionKind;             // 'single' / 'multiple' / 'select_incorrect'
  final List<String> userAnswers;        // ユーザー選択（複数対応）
  final List<String> correctAnswers;     // 正答（複数対応）

  // --- 互換getter（旧UI用） ---
  String? get userAnswer => userAnswers.isNotEmpty ? userAnswers.first : null;
  String  get correct    => correctAnswers.isNotEmpty ? correctAnswers.first : '';

  /// 正誤判定
  /// - multiple: 完全一致（順不同）
  /// - select_incorrect: 正解集合（=誤り集合）とユーザー選択が1つでも重なれば正解
  /// - single: 完全一致
  bool get isCorrect {
    final ua = userAnswers.toSet();
    final ca = correctAnswers.toSet();

    if (ua.isEmpty || ca.isEmpty) return false;

    switch (questionKind) {
      case 'multiple':
      // 複数正答 → 完全一致
        return ua.length == ca.length && ua.containsAll(ca);
      case 'select_incorrect':
      // 誤答選択 → 誤り（=正解集合）から1つでも選べていれば正解
        return ua.intersection(ca).isNotEmpty;
      default:
      // single（その他）→ 完全一致
        return ua.length == ca.length && ua.containsAll(ca);
    }
  }

  const AnswerRecord({
    required this.id,
    required this.ts,
    required this.difficulty,
    required this.domain,
    required this.major,
    required this.mid,
    required this.topic,
    required this.question,
    required this.choices,
    required this.explanation,
    required this.rationales,
    this.choiceCount = 4,
    this.questionKind = 'single',
    List<String>? userAnswers,
    List<String>? correctAnswers,
  })  : userAnswers = userAnswers ?? const <String>[],
        correctAnswers = correctAnswers ?? const <String>[];

  /// 後方互換を考慮した読み込み
  factory AnswerRecord.fromJson(Map<String, dynamic> j) {
    final version = (j['schemaVersion'] as int?) ?? 1;

    // 共通部の取り出し（壊れ値に強く）
    DateTime _parseTs(dynamic v) {
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = DateTime.tryParse(v);
        if (p != null) return p;
        final asInt = int.tryParse(v);
        if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.now();
    }

    Map<String, String> _parseChoices(dynamic m) {
      if (m is Map) {
        return m.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return const <String, String>{};
    }

    final id          = (j['id'] ?? '').toString();
    final ts          = _parseTs(j['ts']);
    final difficulty  = (j['difficulty'] ?? '').toString();
    final domain      = j['domain']?.toString();
    final major       = j['major']?.toString();
    final mid         = j['mid']?.toString();
    final topic       = j['topic']?.toString();
    final question    = (j['question'] ?? '').toString();
    final choices     = _parseChoices(j['choices']);
    final explanation = j['explanation']?.toString();
    final rationales  = (j['rationales'] is Map)
        ? (j['rationales'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : null;

    // ラベル正規化（' a ' → 'A'）
    List<String> _normList(dynamic any) {
      if (any is List) {
        final set = <String>{};
        for (final e in any) {
          final s = e?.toString().trim().toUpperCase() ?? '';
          if (s.isNotEmpty) set.add(s);
        }
        final out = set.toList()..sort();
        return out;
      }
      return const <String>[];
    }

    // choiceCount の妥当化（未指定は choices.length、最低2）
    int _resolveChoiceCount(int? raw) {
      final fromChoices = choices.length;
      final n = raw ?? fromChoices;
      return n.clamp(2, 26);
    }

    if (version >= 2) {
      final cc   = _resolveChoiceCount(j['choiceCount'] as int?);
      final kind = (j['questionKind'] ?? 'single').toString();
      final ua   = _normList(j['userAnswers']);
      final ca   = _normList(j['correctAnswers']);
      return AnswerRecord(
        id: id,
        ts: ts,
        difficulty: difficulty,
        domain: domain,
        major: major,
        mid: mid,
        topic: topic,
        question: question,
        choices: choices,
        explanation: explanation,
        rationales: rationales,
        choiceCount: cc,
        questionKind: kind,
        userAnswers: ua,
        correctAnswers: ca,
      );
    } else {
      // 旧形式 → 新形式に変換
      final ua = j['userAnswer']?.toString();
      final ca = j['correct']?.toString();

      final uaList = <String>[];
      final caList = <String>[];
      if (ua != null && ua.trim().isNotEmpty) {
        uaList.add(ua.trim().toUpperCase());
      }
      if (ca != null && ca.trim().isNotEmpty) {
        caList.add(ca.trim().toUpperCase());
      }

      return AnswerRecord(
        id: id,
        ts: ts,
        difficulty: difficulty,
        domain: domain,
        major: major,
        mid: mid,
        topic: topic,
        question: question,
        choices: choices,
        explanation: explanation,
        rationales: rationales,
        choiceCount: _resolveChoiceCount(4),
        questionKind: 'single',
        userAnswers: uaList,
        correctAnswers: caList,
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'id': id,
    'ts': ts.millisecondsSinceEpoch,
    'difficulty': difficulty,
    'domain': domain,
    'major': major,
    'mid': mid,
    'topic': topic,
    'question': question,
    'choices': choices,
    'explanation': explanation,
    'rationales': rationales,
    'choiceCount': choiceCount,
    'questionKind': questionKind,
    'userAnswers': userAnswers,
    'correctAnswers': correctAnswers,
  };

  /// 便利: 一部差し替え
  AnswerRecord copyWith({
    String? id,
    DateTime? ts,
    String? difficulty,
    String? domain,
    String? major,
    String? mid,
    String? topic,
    String? question,
    Map<String, String>? choices,
    String? explanation,
    Map<String, String>? rationales,
    int? choiceCount,
    String? questionKind,
    List<String>? userAnswers,
    List<String>? correctAnswers,
  }) {
    return AnswerRecord(
      id: id ?? this.id,
      ts: ts ?? this.ts,
      difficulty: difficulty ?? this.difficulty,
      domain: domain ?? this.domain,
      major: major ?? this.major,
      mid: mid ?? this.mid,
      topic: topic ?? this.topic,
      question: question ?? this.question,
      choices: choices ?? this.choices,
      explanation: explanation ?? this.explanation,
      rationales: rationales ?? this.rationales,
      choiceCount: choiceCount ?? this.choiceCount,
      questionKind: questionKind ?? this.questionKind,
      userAnswers: userAnswers ?? this.userAnswers,
      correctAnswers: correctAnswers ?? this.correctAnswers,
    );
  }
}

/// 履歴の保存・取得（SharedPreferences, List<String>）
/// - ストレージキー: 'answer_history_v3'
/// - 1件=1JSON文字列 で先頭挿入（最新が先頭）
/// - 破損エントリはスキップして読み込む
class AnswerHistory {
  AnswerHistory._();
  static final AnswerHistory instance = AnswerHistory._();

  static const _storageKey = 'answer_history_v3';
  static const _maxKeep = 500;

  Future<List<AnswerRecord>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_storageKey) ?? const <String>[];

    final out = <AnswerRecord>[];
    for (final s in raw) {
      try {
        final obj = jsonDecode(s);
        if (obj is Map<String, dynamic>) {
          out.add(AnswerRecord.fromJson(obj));
        } else if (obj is Map) {
          out.add(AnswerRecord.fromJson(Map<String, dynamic>.from(obj)));
        }
      } catch (_) {
        // 壊れたエントリはスキップ
      }
    }
    return out;
  }

  Future<void> add(AnswerRecord rec) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_storageKey) ?? <String>[];
    list.insert(0, jsonEncode(rec.toJson()));
    if (list.length > _maxKeep) {
      list.removeRange(_maxKeep, list.length);
    }
    await sp.setStringList(_storageKey, list);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_storageKey);
  }
}