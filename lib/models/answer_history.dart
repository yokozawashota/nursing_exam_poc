// lib/models/answer_history.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 解答履歴 1件分
class AnswerRecord {
  final String id;               // 例: epoch_ms 文字列
  final DateTime ts;             // タイムスタンプ
  final String difficulty;       // '必修問題' / '一般問題' / '状況設定問題'
  final String? domain;          // 分野
  final String? major;           // 大項目
  final String? mid;             // 中項目
  final String? topic;           // 小項目（内部選定）

  // スナップショット（本文）
  final String question;
  final Map<String, String> choices;     // A-D
  final String correct;                  // 'A' | 'B' | 'C' | 'D'
  final String? explanation;             // 解説
  final Map<String, String>? rationales; // 可能なら

  // ユーザー回答
  final String? userAnswer;

  bool get isCorrect => userAnswer != null && userAnswer == correct;

  AnswerRecord({
    required this.id,
    required this.ts,
    required this.difficulty,
    required this.domain,
    required this.major,
    required this.mid,
    required this.topic,
    required this.question,
    required this.choices,
    required this.correct,
    required this.explanation,
    required this.rationales,
    required this.userAnswer,
  });

  factory AnswerRecord.fromJson(Map<String, dynamic> j) => AnswerRecord(
    id: j['id'] as String,
    ts: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
    difficulty: (j['difficulty'] ?? '') as String,
    domain: j['domain'] as String?,
    major: j['major'] as String?,
    mid: j['mid'] as String?,
    topic: j['topic'] as String?,
    question: (j['question'] ?? '') as String,
    choices: (j['choices'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
    )?.cast<String, String>() ??
        const <String, String>{},
    correct: (j['correct'] ?? '') as String,
    explanation: j['explanation'] as String?,
    rationales: (j['rationales'] as Map?)
        ?.map((k, v) => MapEntry(k.toString(), v.toString()))
        .cast<String, String>(),
    userAnswer: j['userAnswer'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ts': ts.millisecondsSinceEpoch,
    'difficulty': difficulty,
    'domain': domain,
    'major': major,
    'mid': mid,
    'topic': topic,
    'question': question,
    'choices': choices,
    'correct': correct,
    'explanation': explanation,
    'rationales': rationales,
    'userAnswer': userAnswer,
  };
}

/// 履歴の保存・取得（SharedPreferences）
class AnswerHistory {
  AnswerHistory._();
  static final AnswerHistory instance = AnswerHistory._();

  static const _storageKey = 'answer_history_v3';
  static const _maxKeep = 500;

  Future<List<AnswerRecord>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_storageKey) ?? const <String>[];
    return raw
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .map(AnswerRecord.fromJson)
        .toList();
  }

  Future<void> add(AnswerRecord rec) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_storageKey) ?? <String>[];
    list.insert(0, jsonEncode(rec.toJson()));
    if (list.length > _maxKeep) list.removeRange(_maxKeep, list.length);
    await sp.setStringList(_storageKey, list);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_storageKey);
  }
}