// lib/services/response_parser.dart
//
// LLM 応答(JSON文字列)を画面向けの Map 形式に正規化する。
// 新仕様：LLMの出力を尊重し、整形・矯正は最小限（choices / correctAnswers の整合性チェックのみ）。

import 'dart:convert';
import 'package:flutter/foundation.dart';

class ResponseParser {
  /// content(JSON文字列) → 画面がそのまま使える Map に整形
  static Map<String, dynamic> parseContentToQuestion(
      String content, {
        required String difficulty,
        required String domain,
        required String major,
        String? mid,
        String? topic,
      }) {
    final Map<String, dynamic> meta = {
      'difficulty': difficulty,
      'domain': domain,
      'major': major,
      if (mid != null) 'mid': mid,
      if (topic != null) 'topic': topic,
    };

    // ===== JSON 取り出し =====
    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      final extracted = _extractJsonObject(content);
      obj = jsonDecode(extracted) as Map<String, dynamic>;
    }

    // ===== 基本構造の取得 =====
    final String question = (obj['question'] ?? '').toString().trim();
    final Map<String, String> choices = _normalizeChoices(obj['choices']);
    final List<String> correctAnswers =
    _normalizeCorrectAnswers(obj, choices.keys.toList());
    final String kind =
    (obj['questionKind'] ?? obj['kind'] ?? 'single').toString();
    final String explanation = (obj['explanation'] ?? '').toString();
    final Map<String, String>? rationales =
    _normalizeRationales(obj['rationales']);

    // ===== 整合性チェック =====
    final orderedKeys =
    ['A', 'B', 'C', 'D', 'E'].where(choices.containsKey).toList();
    final Map<String, String> orderedChoices = {
      for (final k in orderedKeys) k: choices[k]!,
    };

    final filteredCorrect =
    correctAnswers.where(orderedChoices.containsKey).toList();

    _debugPrint('--- ResponseParser ---');
    _debugPrint('kind=$kind  choices=${orderedChoices.keys}  correct=$filteredCorrect');

    return {
      'question': question,
      'choices': orderedChoices,
      'correctAnswers': filteredCorrect,
      'explanation': explanation,
      'rationales': rationales,
      'questionKind': kind,
      'meta': meta,
    };
  }

  // ------------------------------------------------------------
  // 正規化ヘルパ
  // ------------------------------------------------------------

  static Map<String, String> _normalizeChoices(dynamic raw) {
    if (raw is List) {
      final Map<String, String> out = {};
      int auto = 0;
      for (final e in raw) {
        final s = e.toString().trim();
        final m = RegExp(r'^([A-E])[\.\)]\s*(.*)$').firstMatch(s);
        if (m != null) {
          out[m.group(1)!] = (m.group(2) ?? '').trim();
        } else {
          final label = String.fromCharCode('A'.codeUnitAt(0) + auto);
          out[label] = s;
          auto++;
        }
      }
      return out;
    }

    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString().trim(), v.toString().trim()));
    }

    return {};
  }

  static List<String> _normalizeCorrectAnswers(
      Map<String, dynamic> obj, List<String> orderedLabels) {
    if (obj['correctAnswers'] is List) {
      return (obj['correctAnswers'] as List)
          .map((e) => _toLabel(e))
          .where((label) => orderedLabels.contains(label))
          .toList();
    }
    return [];
  }

  static Map<String, String>? _normalizeRationales(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString().trim(), v.toString().trim()));
    }
    return null;
  }

  static String _toLabel(dynamic v) {
    final s = v.toString().trim();
    if (s.isEmpty) return 'A';
    final first = s[0].toUpperCase();
    if ('ABCDE'.contains(first)) return first;
    return 'A';
  }

  // ------------------------------------------------------------
  // JSON抽出（```json ... ```対応）
  // ------------------------------------------------------------
  static String _extractJsonObject(String s) {
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fm = fence.firstMatch(s);
    final body = fm != null ? fm.group(1) ?? '' : s;

    final start = body.indexOf('{');
    if (start < 0) return '{}';
    int depth = 0;
    for (int i = start; i < body.length; i++) {
      final ch = body[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return body.substring(start, i + 1);
        }
      }
    }
    return '{}';
  }

  static void _debugPrint(String msg) {
    debugPrint('[ResponseParser] $msg');
  }
}