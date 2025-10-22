// lib/utils/choice_logic.dart
import 'dart:math';

/// シャッフル後の選択肢と、正答ラベルを持ち回るためのDTO
class ShuffledChoices {
  final Map<String, String> choices; // 例: {'A': '...', 'B': '...'}
  final String correct;              // 例: 'B'
  const ShuffledChoices({required this.choices, required this.correct});
}

/// 与えられた選択肢をシャッフルし、A,B,C,D,(E) で再ラベリングして返す。
/// [rawChoices] は List でも Map でもOK
/// [rawCorrect] は 'A' などのラベル もしくは index(int) も許容（Map の場合はラベル必須）。
/// [maxChoices] で上限を指定（既定5。既存の4択想定とも互換）
/// [rng] を渡すとテストで決定的にできます（未指定なら Random() ）。
///
/// 戻り値：ShuffledChoices（choices: Map, correct: ラベル）
ShuffledChoices shuffleWithRelabel(
    dynamic rawChoices,
    dynamic rawCorrect, {
      int maxChoices = 5,
      Random? rng,
    }) {
  final Random _rng = rng ?? Random();

  // まず配列化（順序をもつ一次リスト化）
  final List<String> list = _toList(rawChoices);

  // 上限（2〜maxChoices）を適用
  final int n = list.length.clamp(2, maxChoices);

  // シャッフルに使うインデックス
  final idxs = List<int>.generate(n, (i) => i);
  idxs.shuffle(_rng);

  // 新しいラベル
  const labels = ['A', 'B', 'C', 'D', 'E', 'F']; // 将来拡張用に余裕あり
  final newMap = <String, String>{};
  for (var i = 0; i < n; i++) {
    newMap[labels[i]] = list[idxs[i]];
  }

  // 正答の追随
  String? correctLabel;

  // 1) 数値インデックス
  if (rawCorrect is int) {
    final origIndex = rawCorrect;
    if (origIndex >= 0 && origIndex < n) {
      final newPos = idxs.indexOf(origIndex);
      if (newPos >= 0) correctLabel = labels[newPos];
    }
  }
  // 2) 文字ラベル or テキスト
  else if (rawCorrect is String) {
    final normalized = rawCorrect.trim();

    // 2-1) 'A'.. をインデックスに解釈できるか
    final origIndex = _labelToIndex(normalized.toUpperCase());
    if (origIndex != null && origIndex < n) {
      final newPos = idxs.indexOf(origIndex);
      if (newPos >= 0) correctLabel = labels[newPos];
    } else {
      // 2-2) テキスト一致（大文字小文字・前後空白を無視）
      final target = normalized.toLowerCase();
      for (var i = 0; i < n; i++) {
        if (list[idxs[i]].trim().toLowerCase() == target) {
          correctLabel = labels[i];
          break;
        }
      }
    }
  }
  // 3) その他（オブジェクトなど）→ 文字列化して厳密一致
  else if (rawCorrect != null) {
    final target = rawCorrect.toString();
    for (var i = 0; i < n; i++) {
      if (list[idxs[i]] == target) {
        correctLabel = labels[i];
        break;
      }
    }
  }

  // フォールバック：
  // 何も決まらないときは、元の0番要素が入った位置のラベルを正答にする（以前の常に 'A' より自然）
  correctLabel ??= labels[idxs.indexOf(0).clamp(0, n - 1)];

  return ShuffledChoices(choices: newMap, correct: correctLabel);
}

List<String> _toList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => (e ?? '').toString())
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is Map) {
    // ラベル順 A,B,C,D,E... に並べ替えて拾う
    final entries = raw.entries
        .map((e) => MapEntry(e.key.toString().toUpperCase(), e.value.toString()))
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => e.value.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  // 文字列単体などは空扱い
  return <String>[];
}

int? _labelToIndex(String s) {
  if (s.length != 1) return null;
  final code = s.codeUnitAt(0);
  final a = 'A'.codeUnitAt(0);
  final z = 'Z'.codeUnitAt(0);
  if (code < a || code > z) return null;
  return code - a;
}