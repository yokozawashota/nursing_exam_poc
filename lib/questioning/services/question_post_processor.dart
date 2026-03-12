// lib/questioning/services/question_post_processor.dart
import 'dart:math';

class QuestionPostProcessor {
  const QuestionPostProcessor._();

  static Map<String, dynamic> process({
    required Map<String, dynamic> parsed,
    required String desiredKind,
    required int requiredCorrectCount,
  }) {
    final out = Map<String, dynamic>.from(parsed);

    final Map<String, String>? outChoices =
    (out['choices'] as Map?)?.map((k, v) => MapEntry('$k', '$v'));

    final List<String> outCorrect = ((out['correctAnswers'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    if (outChoices == null) {
      return out;
    }

    // 1) 正答が choices に含まれない場合の安全弁
    final present = outChoices.keys.toSet();
    final filtered = outCorrect.where(present.contains).toList();
    out['correctAnswers'] = filtered.isNotEmpty
        ? filtered
        : (outChoices.isNotEmpty ? [outChoices.keys.first] : []);

    // 2) 問題文に「nつ選んでください」を付与
    final isMulti =
        desiredKind == 'multiple' || desiredKind == 'select_incorrect';
    final q = (out['question'] as String? ?? '').trim();
    out['question'] = _ensureCountInstruction(
      q,
      isMulti: isMulti,
      requiredCorrectCount: requiredCorrectCount,
    );

    // 3) 正答位置を完全ランダム化（毎回シャッフル）
    final remapped = _remapChoicesRandom(
      originalChoices: outChoices,
      originalCorrectLabels: (out['correctAnswers'] as List).cast<String>(),
      originalRationales: (out['rationales'] as Map?)?.cast<String, String>(),
    );

    out['choices'] = remapped.choices;
    out['correctAnswers'] = remapped.corrects;
    if (remapped.rationales != null) {
      out['rationales'] = remapped.rationales;
    }

    return out;
  }

  static String ensureCountInstructionForTest(
      String q, {
        required bool isMulti,
        required int requiredCorrectCount,
      }) {
    return _ensureCountInstruction(
      q,
      isMulti: isMulti,
      requiredCorrectCount: requiredCorrectCount,
    );
  }

  static String _ensureCountInstruction(
      String q, {
        required bool isMulti,
        required int requiredCorrectCount,
      }) {
    if (!isMulti || requiredCorrectCount <= 1) return q;

    final already =
    RegExp(r'[0-9一二三四五六七八九十]+\s*つ\s*選んでください').hasMatch(q);
    if (already) return q;

    return '$q ${requiredCorrectCount}つ選んでください';
  }

  static _RemapResult _remapChoicesRandom({
    required Map<String, String> originalChoices,
    required List<String> originalCorrectLabels,
    Map<String, String>? originalRationales,
  }) {
    final labels =
    ['A', 'B', 'C', 'D', 'E'].where(originalChoices.containsKey).toList();
    final n = labels.length;
    if (n <= 1) {
      return _RemapResult(
        Map<String, String>.from(originalChoices),
        List<String>.from(originalCorrectLabels),
        originalRationales == null
            ? null
            : Map<String, String>.from(originalRationales),
      );
    }

    final rng = Random(DateTime.now().microsecondsSinceEpoch);
    final entries = <MapEntry<String, String>>[
      for (final k in labels) MapEntry(k, originalChoices[k]!)
    ]..shuffle(rng);

    final originalCorrectSet = originalCorrectLabels.toSet();

    final newChoices = <String, String>{};
    final newCorrects = <String>[];
    final Map<String, String>? newRationales =
    originalRationales != null ? <String, String>{} : null;

    for (var i = 0; i < entries.length; i++) {
      final newLabel = String.fromCharCode('A'.codeUnitAt(0) + i);
      final e = entries[i];

      newChoices[newLabel] = e.value;

      if (originalCorrectSet.contains(e.key)) {
        newCorrects.add(newLabel);
      }

      if (newRationales != null) {
        final r = originalRationales![e.key];
        if (r != null && r.trim().isNotEmpty) {
          newRationales[newLabel] = r;
        }
      }
    }

    return _RemapResult(newChoices, newCorrects, newRationales);
  }
}

class _RemapResult {
  final Map<String, String> choices;
  final List<String> corrects;
  final Map<String, String>? rationales;

  const _RemapResult(this.choices, this.corrects, this.rationales);
}