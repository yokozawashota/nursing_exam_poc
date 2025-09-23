// lib/services/response_parser.dart
//
// OpenAI応答(JSON) → 画面用の標準形へ正規化。
// Phase2-B: 5択まで許容、単一/複数正答、誤答選択(select_incorrect)に対応。
// - 戻り値: {
//     question: String,
//     choices: Map<String,String>  // 'A'..'E' → 本文
//     correct: String              // 旧互換（単一の場合のみ）
//     correctAnswers: List<String> // 新：複数にも対応（常に配列で返す）
//     questionKind: 'single' | 'multiple' | 'select_incorrect',
//     explanation: String,
//     rationales?: Map<String,String>,
//     meta: {difficulty, domain, major, mid?, topic?}
//   }

import 'dart:convert';
import 'dart:math';

class ResponseParser {
  static Map<String, dynamic> parseContentToQuestion(
      String content, {
        required String difficulty,
        required String domain,
        required String major,
        String? mid,
        String? topic,
      }) {
    // 1) JSONを解釈（失敗時は安全側）
    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      obj = {
        'question': content,
        'choices': const [],
        'correctIndex': 0,
      };
    }

    final question =
    (obj['question'] ?? obj['stem'] ?? '').toString().trim();

    // choices: List or Map を許容 → 一旦 List<String> に正規化
    final rawChoices = obj['choices'] ?? obj['options'] ?? obj['answers'] ?? [];
    final List<String> baseList = _choicesToList(rawChoices);

    // correct: index / label / text / 配列 のいずれか
    final rawCorrect = obj['correctAnswers'] ??
        obj['correctIndexList'] ??
        obj['correctIndex'] ??
        obj['correct'] ??
        obj['answer'] ??
        obj['correctAnswer'];

    // 説明/ラショナーレ
    final explanation = (obj['explanation'] ?? obj['why'] ?? '').toString();
    Map<String, String>? rationales;
    final rRaw = obj['rationales'] ?? obj['reasons'];
    if (rRaw is Map) {
      rationales = rRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    // 2) questionKind の推定
    //   - 明示フィールド優先: 'questionKind' / 'type' / 'mode'
    //   - 次点: 'askFor' / 'instruction' / 'directive' に "誤っている" 等が含まれるか
    String questionKind = _detectKind(obj);

    // 3) 正答を “元の並び” のインデックス集合へ
    final Set<int> correctIdx = _resolveCorrectIndices(
      rawCorrect,
      baseList,
      originalLabels: _extractLabelsIfMap(rawChoices),
    );

    // 4) 最大5択まででシャッフル＆再ラベル（A..E）
    final cappedN = baseList.length.clamp(2, 5);
    final idxs = List<int>.generate(cappedN, (i) => i);
    idxs.shuffle(Random());

    const labels = ['A', 'B', 'C', 'D', 'E'];
    final choices = <String, String>{};
    for (var i = 0; i < cappedN; i++) {
      choices[labels[i]] = baseList[idxs[i]];
    }

    // 5) 正答（複数可）を新ラベルへ追随
    final List<String> correctAnswers = [];
    for (final orig in correctIdx) {
      if (orig >= 0 && orig < cappedN) {
        final newPos = idxs.indexOf(orig);
        if (newPos >= 0) correctAnswers.add(labels[newPos]);
      }
    }
    // フォールバック：何も解決できない場合は 'A'
    if (correctAnswers.isEmpty) correctAnswers.add('A');

    // 6) 種別の最終決定（明示が無い場合は正答数で判定）
    if (questionKind == 'single' || questionKind == 'multiple') {
      // そのまま
    } else if (questionKind == 'select_incorrect') {
      // 誤答選択型（UIは今は単一/複数の見た目に影響させない）
      // 将来、UI側に注記を出したり複数選択を許可する場合はここを利用
    } else {
      // 未定義 → 正答数で推定
      questionKind = (correctAnswers.length == 1) ? 'single' : 'multiple';
    }

    return {
      'question': question,
      'choices': choices,
      // 旧互換（単一の場合のみ有効）
      'correct': correctAnswers.first,
      // 新（常に配列で返す）
      'correctAnswers': correctAnswers,
      'questionKind': questionKind,
      'explanation': explanation,
      if (rationales != null) 'rationales': rationales,
      'meta': {
        'difficulty': difficulty,
        'domain': domain,
        'major': major,
        if (mid != null) 'mid': mid,
        if (topic != null) 'topic': topic,
      },
    };
  }

  // ----- helpers -----

  /// choices を List<String> に正規化
  static List<String> _choicesToList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (raw is Map) {
      // ラベル順で拾う（A,B,C..）
      final entries = raw.entries
          .map((e) => MapEntry(e.key.toString().toUpperCase(), e.value.toString()))
          .toList();
      entries.sort((a, b) => a.key.compareTo(b.key));
      return entries.map((e) => e.value).where((s) => s.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }

  /// 元が Map のときのラベル配列（A,B,C..）を返す。それ以外は null。
  static List<String>? _extractLabelsIfMap(dynamic raw) {
    if (raw is Map) {
      final keys = raw.keys.map((e) => e.toString().toUpperCase()).toList();
      keys.sort();
      return keys;
    }
    return null;
  }

  /// rawCorrect（index/label/text/配列）を “元リストの index 集合” に変換
  static Set<int> _resolveCorrectIndices(
      dynamic rawCorrect,
      List<String> baseList, {
        List<String>? originalLabels,
      }) {
    final out = <int>{};

    void addByLabel(String s) {
      final u = s.trim().toUpperCase();
      if (u.length == 1) {
        final code = u.codeUnitAt(0) - 'A'.codeUnitAt(0);
        if (code >= 0 && code < baseList.length) {
          out.add(code);
        }
      }
    }

    void addByText(String t) {
      final txt = t.toString();
      final idx = baseList.indexWhere(
            (e) => e.toString().trim() == txt.trim(),
      );
      if (idx >= 0) out.add(idx);
    }

    if (rawCorrect is List) {
      for (final c in rawCorrect) {
        if (c is int) {
          if (c >= 0 && c < baseList.length) out.add(c);
        } else if (c is String) {
          // ラベル or 文字列本文
          if (originalLabels != null && originalLabels.contains(c.toUpperCase())) {
            addByLabel(c);
          } else {
            // ラベルでないなら本文マッチ
            addByText(c);
          }
        }
      }
    } else if (rawCorrect is int) {
      if (rawCorrect >= 0 && rawCorrect < baseList.length) out.add(rawCorrect);
    } else if (rawCorrect is String) {
      if (originalLabels != null && originalLabels.contains(rawCorrect.toUpperCase())) {
        addByLabel(rawCorrect);
      } else {
        addByText(rawCorrect);
      }
    }

    // フォールバック
    if (out.isEmpty) out.add(0);
    return out;
  }

  /// questionKind の推定
  static String _detectKind(Map<String, dynamic> obj) {
    final candidates = [
      obj['questionKind'],
      obj['type'],
      obj['mode'],
      obj['askFor'],
      obj['instruction'],
      obj['directive'],
    ].where((e) => e != null).map((e) => e.toString().toLowerCase()).toList();

    // 明示的なキー/値で判定
    for (final s in candidates) {
      if (s.contains('select_incorrect') ||
          s.contains('choose_incorrect') ||
          s.contains('incorrect')) {
        return 'select_incorrect';
      }
      if (s.contains('multiple') || s.contains('multi')) {
        return 'multiple';
      }
      if (s.contains('single')) {
        return 'single';
      }
      // 日本語の簡易推定
      if (s.contains('誤っている') || s.contains('誤り') || s.contains('不適切')) {
        return 'select_incorrect';
      }
      if (s.contains('複数') || s.contains('二つ選べ') || s.contains('二つ以上')) {
        return 'multiple';
      }
    }
    // 指定なし
    return 'unknown';
  }
}