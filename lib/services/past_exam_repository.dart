// lib/services/past_exam_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/nurai_question.dart';

/// 国試過去問を読み込むリポジトリ（assets）
///
/// ✅対応方針
/// - assets/past_exam/<examId>/<partKey>.json を読む
/// - JSONの形式は「旧/新/別名」どれも受ける（後方互換）
///   - 旧: questionText / correctLabels / rationales
///   - 新: question / correctAnswers / rationales
///   - 別名: answer(単一) / choiceRationales
/// - ✅ choices が空の “計算問題” を許容（clamp事故を防ぐ）
class PastExamRepository {
  PastExamRepository._();
  static final PastExamRepository instance = PastExamRepository._();

  Future<List<NuraiQuestion>> load({
    required String examId,
    required String partKey,
  }) async {
    final path = _assetPath(examId: examId, partKey: partKey);
    final text = await rootBundle.loadString(path);

    final decoded = jsonDecode(text);
    if (decoded is! List) return const <NuraiQuestion>[];

    final out = <NuraiQuestion>[];
    for (final e in decoded) {
      if (e is Map<String, dynamic>) {
        out.add(_fromJson(e, examId: examId, partKey: partKey));
      } else if (e is Map) {
        out.add(
          _fromJson(
            Map<String, dynamic>.from(e),
            examId: examId,
            partKey: partKey,
          ),
        );
      }
    }
    return out;
  }

  Future<List<NuraiQuestion>> load113HisshuAm() async {
    return load(examId: '113', partKey: 'hisshu_am');
  }

  Future<List<NuraiQuestion>> loadAll() async {
    return load113HisshuAm();
  }

  String _assetPath({required String examId, required String partKey}) {
    return 'assets/past_exam/$examId/$partKey.json';
  }

  NuraiQuestion _fromJson(
      Map<String, dynamic> j, {
        required String examId,
        required String partKey,
      }) {
    // ---- questionText（旧） or question（新）----
    final questionText = (j['questionText'] ?? j['question'] ?? '').toString();

    // ---- choices ----
    final Map<String, String> choices =
    (j['choices'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));

    // ---- correct labels ----
    final List<String> correctLabels = _parseCorrectLabels(j);

    // ---- rationales ----
    final Map<String, String>? rationales = _parseRationales(j);

    // ---- image ----
    final bool imageRequired = (j['imageRequired'] == true);
    final String? imagePathRaw = j['imagePath']?.toString().trim();
    final String? imagePath = (imagePathRaw != null && imagePathRaw.isNotEmpty) ? imagePathRaw : null;

    // ---- question kind ----
    final rawKind = (j['questionKind'] ?? 'single').toString();
    final kind = choices.isEmpty ? 'input' : rawKind;

    // ---- requiredCorrectCount ----
    final int requiredCorrectCount =
        (j['requiredCorrectCount'] as int?) ??
            (choices.isEmpty ? 1 : correctLabels.length.clamp(1, choices.length));

    // ---- difficulty ----
    final difficulty = (j['difficulty']?.toString().trim().isNotEmpty == true)
        ? j['difficulty'].toString()
        : _difficultyFromPartKey(partKey);

    final domain = j['domain']?.toString() ?? '';
    final major = j['major']?.toString() ?? '';

    return NuraiQuestion(
      questionText: questionText,
      choices: choices,
      correctLabels: correctLabels,
      rationales: rationales,
      explanation: j['explanation']?.toString(),
      questionKind: kind,
      requiredCorrectCount: requiredCorrectCount,
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: j['mid']?.toString(),
      topic: j['topic']?.toString(),
      sourceType: j['sourceType']?.toString() ?? 'past_exam',
      sourceTag: j['sourceTag']?.toString(),

      // ✅ ここが「画像が出なくなった」原因になりやすい箇所
      imageRequired: imageRequired,
      imagePath: imagePath,
    );
  }

  List<String> _parseCorrectLabels(Map<String, dynamic> j) {
    final list = _parseLabelList(j['correctLabels']) + _parseLabelList(j['correctAnswers']);
    if (list.isNotEmpty) return _normalizeLabels(list);

    final ans = (j['answer'] ?? '').toString().trim();
    if (ans.isNotEmpty) return _normalizeLabels([ans]);

    return const <String>[];
  }

  Map<String, String>? _parseRationales(Map<String, dynamic> j) {
    dynamic v = j['rationales'];
    v ??= j['choiceRationales'];

    if (v is Map) {
      final m = v.map((k, vv) => MapEntry(k.toString(), vv.toString()));
      return m.isEmpty ? null : m;
    }
    return null;
  }

  List<String> _parseLabelList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    return const <String>[];
  }

  List<String> _normalizeLabels(List<String> labels) {
    final out = <String>[];
    final set = <String>{};
    for (final s in labels) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (set.add(t)) out.add(t);
    }
    return out;
  }

  String _difficultyFromPartKey(String partKey) {
    if (partKey.startsWith('hisshu')) return '必修問題';
    if (partKey.startsWith('ippan')) return '一般問題';
    if (partKey.startsWith('scenario')) return '状況設定問題';
    return '過去問';
  }
}