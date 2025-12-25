// lib/services/past_exam_repository.dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/nurai_question.dart';

/// 画面用：パート表示メタ
class PastExamPartMeta {
  final String label;       // 例: 必修問題 午前
  final String description; // 例: 必修 午前の問題を解く
  final String partKey;     // 例: hisshu_am
  final bool enabled;

  const PastExamPartMeta({
    required this.label,
    required this.description,
    required this.partKey,
    this.enabled = true,
  });
}

class PastExamRepository {
  PastExamRepository._();
  static final PastExamRepository instance = PastExamRepository._();

  /// ====== 公開API（画面が壊れないよう固定） ======
  ///
  /// - partsForExam(examId): その年度で利用可能なJSONパートを自動検出
  /// - load(examId, partKey): 1パートの問題を読み込み
  /// - totalQuestionsOfExam(examId): その年度の総問題数（全パート合計）
  ///
  /// pubspec.yaml を
  ///   - assets/past_exam/
  ///   - assets/fig/
  /// の「ディレクトリ指定」にしても AssetManifest から列挙できるようにする。

  // ---- キャッシュ ----
  Map<String, dynamic>? _assetManifest;
  final Map<String, List<PastExamPartMeta>> _partsCache = {};
  final Map<String, int> _totalCache = {};

  Future<Map<String, dynamic>> _loadManifest() async {
    if (_assetManifest != null) return _assetManifest!;
    final raw = await rootBundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(raw);
    final map = Map<String, dynamic>.from(decoded as Map);
    _assetManifest = map;
    return map;
  }

  /// assets/past_exam/<examId>/ 配下の json を列挙して partKey を作る
  Future<List<PastExamPartMeta>> partsForExam(String examId) async {
    if (_partsCache.containsKey(examId)) return _partsCache[examId]!;

    final manifest = await _loadManifest();
    final prefix = 'assets/past_exam/$examId/';
    final keys = manifest.keys
        .where((k) => k.startsWith(prefix) && k.toLowerCase().endsWith('.json'))
        .toList()
      ..sort();

    if (keys.isEmpty) {
      _partsCache[examId] = const [];
      return const [];
    }

    final parts = <PastExamPartMeta>[];
    for (final path in keys) {
      final file = path.split('/').last; // hisshu_am.json
      final partKey = file.replaceAll('.json', '');

      final label = _labelFromPartKey(partKey);
      final desc = _descFromPartKey(partKey);

      parts.add(
        PastExamPartMeta(
          label: label.isEmpty ? partKey : label,
          description: desc.isEmpty ? 'このパートの問題を解く' : desc,
          partKey: partKey,
          enabled: true,
        ),
      );
    }

    _partsCache[examId] = parts;
    return parts;
  }

  /// 1パート読み込み（固定API名：load）
  Future<List<NuraiQuestion>> load({
    required String examId,
    required String partKey,
  }) async {
    final assetPath = 'assets/past_exam/$examId/$partKey.json';
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! List) return const [];

    final out = <NuraiQuestion>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;

      final j = Map<String, dynamic>.from(item as Map);

      final questionText = (j['question'] ?? j['questionText'] ?? '').toString();

      final choicesRaw = j['choices'];
      final choices = <String, String>{};
      if (choicesRaw is Map) {
        final m = Map<String, dynamic>.from(choicesRaw as Map);
        for (final e in m.entries) {
          choices[e.key.toString()] = (e.value ?? '').toString();
        }
      }

      final ca = j['correctAnswers'] ?? j['correctLabels'] ?? j['answer'];
      final correctLabels = <String>[];
      if (ca is List) {
        correctLabels.addAll(
          ca.map((e) => (e ?? '').toString()).where((s) => s.trim().isNotEmpty),
        );
      } else if (ca != null) {
        final s = ca.toString().trim();
        if (s.isNotEmpty) correctLabels.add(s);
      }

      // ✅ 根拠：choiceRationales のみ対応（rationales はフォローしない）
      final rk = j['choiceRationales'];
      Map<String, String>? rationales;
      if (rk is Map) {
        final m = Map<String, dynamic>.from(rk as Map);
        rationales = m.map((k, v) => MapEntry(k.toString(), (v ?? '').toString()));
      }

      final explanation = j['explanation']?.toString();

      final questionKind = (j['questionKind'] ?? j['kind'] ?? 'single').toString();
      final requiredCorrectCount = (j['requiredCorrectCount'] is int)
          ? (j['requiredCorrectCount'] as int)
          : (correctLabels.isNotEmpty ? correctLabels.length : 1);

      final sourceType = (j['sourceType'] ?? 'past_exam').toString();

      // sourceTag：無ければ自動生成（キー安定用）
      final sourceTag = (j['sourceTag'] ?? j['tag'] ?? '').toString().trim().isNotEmpty
          ? (j['sourceTag'] ?? j['tag']).toString()
          : _defaultSourceTag(examId: examId, partKey: partKey, index1: i + 1);

      // 画像：figure / imagePath を許容
      final imagePath = (j['imagePath'] ?? j['figure'])?.toString();
      final imageRequired = (j['imageRequired'] == true);

      out.add(
        NuraiQuestion(
          questionText: questionText,
          choices: choices,
          correctLabels: correctLabels,
          rationales: rationales,
          explanation: explanation,
          questionKind: questionKind,
          requiredCorrectCount: requiredCorrectCount,
          difficulty: (j['difficulty'] ?? '').toString(),
          domain: (j['domain'] ?? '').toString(),
          major: (j['major'] ?? '').toString(),
          mid: j['mid']?.toString(),
          topic: j['topic']?.toString(),
          sourceType: sourceType,
          sourceTag: sourceTag,
          imagePath: imagePath,
          imageRequired: imageRequired,
        ),
      );
    }

    return out;
  }

  /// 総問題数（全パート合算）
  Future<int> totalQuestionsOfExam(String examId) async {
    if (_totalCache.containsKey(examId)) return _totalCache[examId]!;

    final parts = await partsForExam(examId);
    if (parts.isEmpty) {
      _totalCache[examId] = 0;
      return 0;
    }

    var total = 0;
    for (final p in parts) {
      try {
        final list = await load(examId: examId, partKey: p.partKey);
        total += list.length;
      } catch (_) {
        // 読めないパートは 0 として続行（クラッシュ防止）
      }
    }

    _totalCache[examId] = total;
    return total;
  }

  /// 年度追加時などでキャッシュを捨てたい場合に呼べる（任意）
  void clearCache() {
    _assetManifest = null;
    _partsCache.clear();
    _totalCache.clear();
  }

  // ====== 表示名生成 ======

  String _labelFromPartKey(String partKey) {
    // 例: hisshu_am / ippan_pm / situation_am
    final lower = partKey.toLowerCase();

    String kind = '';
    if (lower.startsWith('hisshu')) kind = '必修問題';
    if (lower.startsWith('ippan')) kind = '一般問題';
    if (lower.startsWith('situation')) kind = '状況設定問題';

    String time = '';
    if (lower.endsWith('_am')) time = '午前';
    if (lower.endsWith('_pm')) time = '午後';

    if (kind.isEmpty && time.isEmpty) return '';
    return [kind, time].where((s) => s.isNotEmpty).join(' ');
  }

  String _descFromPartKey(String partKey) {
    final label = _labelFromPartKey(partKey);
    if (label.isEmpty) return '';
    // 「必修問題 午前」→「必修 午前の問題を解く」
    final t = label.replaceAll('問題', '');
    return '$t の問題を解く';
  }

  String _defaultSourceTag({
    required String examId,
    required String partKey,
    required int index1,
  }) {
    // 例: past_exam:111:hisshu_am:1
    return 'past_exam:$examId:$partKey:$index1';
  }
}