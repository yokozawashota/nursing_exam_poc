// lib/services/response_parser.dart
//
// LLM 応答(JSON文字列)を画面向けの Map 形式に正規化する。
// 形式ゆらぎ（配列/マップ/単一値/小文字/数値/インデックス等）に耐えるようガードを強化。
// ★ correctAnswers は LLM の JSON を優先し、rationales では書き換えない方針。

import 'dart:convert';
import 'package:flutter/foundation.dart';

class ResponseParser {
  static const bool _debug = true; // 一旦 true にして挙動を追いやすく

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
      obj = jsonDecode(_stripBom(content).trim()) as Map<String, dynamic>;
    } catch (e) {
      _debugPrint('decode failed (direct): $e');
      final extracted = _extractJsonObject(content);
      obj = jsonDecode(_stripBom(extracted)) as Map<String, dynamic>;
    }

    // ログ：生の correctAnswers
    _debugPrint('raw correctAnswers field = ${obj['correctAnswers']}');

    // ===== 基本構造の取得 =====
    final String question = (obj['question'] ?? '').toString().trim();
    final Map<String, String> choices = _normalizeChoices(obj['choices']);
    final List<String> correctAnswers =
    _normalizeCorrectAnswers(obj, choices.keys.toList());
    final String kind =
    (obj['questionKind'] ?? obj['kind'] ?? 'single').toString();
    final String explanation = (obj['explanation'] ?? '').toString();
    final Map<String, String>? rationales =
    _normalizeRationales(obj['rationales'] ?? obj['reasons'] ?? obj['rationale']);

    // ===== 整合性チェック =====
    final orderedKeys =
    ['A', 'B', 'C', 'D', 'E'].where(choices.containsKey).toList();

    final Map<String, String> orderedChoices = {
      for (final k in orderedKeys) k: choices[k]!,
    };

    // correctAnswers が choices に存在しないラベルを持っていたら落とす
    final filteredCorrect =
    correctAnswers.where(orderedChoices.containsKey).toList();

    // フォールバック：正答が空のときや choices が空のときの保険
    final safeCorrect = filteredCorrect.isNotEmpty
        ? filteredCorrect
        : (orderedChoices.isNotEmpty ? [orderedKeys.first] : <String>[]);

    _debugPrint('--- ResponseParser ---');
    _debugPrint(
        'kind=$kind  choices=${orderedChoices.keys}  safeCorrect=$safeCorrect');

    return {
      'question': question,
      'choices': orderedChoices,
      'correctAnswers': safeCorrect,
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
      // ラベル順 A..E のみ採用（きれいに並べる）
      final order = ['A', 'B', 'C', 'D', 'E'];
      final Map<String, String> out = {};
      for (final k in order) {
        final v = raw[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        out[k] = s;
      }
      // 任意キーしかない場合のフォールバック（順は維持しないが落ちない）
      if (out.isEmpty) {
        raw.forEach((k, v) {
          final kk = k.toString().trim();
          final vv = v.toString().trim();
          if (kk.isNotEmpty && vv.isNotEmpty) out[kk] = vv;
        });
      }
      return out;
    }

    return {};
  }

  static List<String> _normalizeCorrectAnswers(
      Map<String, dynamic> obj,
      List<String> orderedLabels,
      ) {
    final raw = obj['correctAnswers'] ?? obj['answer'] ?? obj['answers'];
    final Set<String> acc = {};

    void addOne(dynamic v) {
      final lab = _toLabel(v);
      if (lab != null) acc.add(lab);
    }

    if (raw is List) {
      for (final v in raw) addOne(v);
    } else if (raw != null) {
      addOne(raw);
    }

    // ラベル順で整列し、存在しないラベルは除外
    final keep = acc.where(orderedLabels.contains).toList()
      ..sort((a, b) =>
          orderedLabels.indexOf(a).compareTo(orderedLabels.indexOf(b)));

    _debugPrint('normalized correctAnswers = $keep');
    return keep;
  }

  static Map<String, String>? _normalizeRationales(dynamic raw) {
    if (raw is Map) {
      return raw
          .map((k, v) => MapEntry(k.toString().trim(), v.toString().trim()));
    }
    return null;
  }

  static String? _toLabel(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    // 数値(0/1/2/3/4) or (1/2/3/4/5) → A..E
    final asInt = int.tryParse(s);
    if (asInt != null) {
      final idx = (asInt >= 1 && asInt <= 5) ? asInt - 1 : asInt; // 1-originにも対応
      if (idx >= 0 && idx < 5) {
        return String.fromCharCode('A'.codeUnitAt(0) + idx);
      }
    }

    final first = s[0].toUpperCase();
    if ('ABCDE'.contains(first)) return first;
    return null;
  }

  // ------------------------------------------------------------
  // JSON抽出（```json ... ```対応）
  // ------------------------------------------------------------
  static String _extractJsonObject(String s) {
    final text = _stripBom(s);

    // フェンス（```json ... ``` or ``` ... ```）を最優先
    final fence = RegExp(
      r'```+\s*json\s*([\s\S]*?)```+|```+\s*([\s\S]*?)```+',
      multiLine: true,
      caseSensitive: false,
    );
    final fm = fence.firstMatch(text);
    final body = fm != null ? (fm.group(1) ?? fm.group(2) ?? '') : text;

    final start = body.indexOf('{');
    if (start < 0) return '{}';

    int depth = 0;
    for (int i = start; i < body.length; i++) {
      final ch = body[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return body.substring(start, i + 1);
        }
      }
    }
    return '{}';
  }

  static String _stripBom(String s) {
    if (s.isEmpty) return s;
    const bom = '\u{FEFF}';
    return s.startsWith(bom) ? s.substring(1) : s;
  }

  static void _debugPrint(String msg) {
    if (_debug) debugPrint('[ResponseParser] $msg');
  }
}