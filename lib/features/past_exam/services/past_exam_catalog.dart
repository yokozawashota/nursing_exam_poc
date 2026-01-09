// lib/features/past_exam/services/past_exam_catalog.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class PastExamCatalog {
  PastExamCatalog._();
  static final PastExamCatalog instance = PastExamCatalog._();

  List<PastExamMeta> _exams = const [];
  bool _loaded = false;

  List<PastExamMeta> get exams => _exams;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    final raw = await rootBundle.loadString('assets/past_exam/catalog.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['exams'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => PastExamMeta.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    _exams = list;
  }

  PastExamMeta? findById(String id) {
    for (final e in _exams) {
      if (e.id == id) return e;
    }
    return null;
  }
}

class PastExamMeta {
  final String id;
  final String title;
  final List<PastExamPartMeta> parts;

  const PastExamMeta({
    required this.id,
    required this.title,
    required this.parts,
  });

  factory PastExamMeta.fromJson(Map<String, dynamic> j) {
    return PastExamMeta(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      parts: ((j['parts'] as List<dynamic>? ?? const []))
          .whereType<Map>()
          .map((p) => PastExamPartMeta.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

class PastExamPartMeta {
  final String key;         // assets/past_exam/<examId>/<key>.json
  final String label;       // 画面表示
  final String description; // 画面表示
  final String kind;        // 必修/一般/状況設定（フィルタ用）

  const PastExamPartMeta({
    required this.key,
    required this.label,
    required this.description,
    required this.kind,
  });

  factory PastExamPartMeta.fromJson(Map<String, dynamic> j) {
    return PastExamPartMeta(
      key: (j['key'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      kind: (j['kind'] ?? '').toString(),
    );
  }
}