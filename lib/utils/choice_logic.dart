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
/// [maxChoices] で上限を指定（Phase1: 5 を許容。既定4の互換は維持）
///
/// 戻り値：ShuffledChoices（choices: Map, correct: ラベル）
ShuffledChoices shuffleWithRelabel(
    dynamic rawChoices,
    dynamic rawCorrect, {
      int maxChoices = 5, // Phase1: 上限5（既存コードとの互換を壊さないようにResponseParser側から制御）
    }) {
  // まず配列化（順序をもつ一次リスト化）
  final List<String> list = _toList(rawChoices);

  // 上限（2〜maxChoices）を適用
  final int n = list.length.clamp(2, maxChoices);

  // シャッフルに使うインデックス
  final idxs = List<int>.generate(n, (i) => i);
  idxs.shuffle(Random());

  // 新しいラベル
  const labels = ['A', 'B', 'C', 'D', 'E', 'F']; // 将来の拡張を見据えて冗長に
  final newMap = <String, String>{};
  for (var i = 0; i < n; i++) {
    newMap[labels[i]] = list[idxs[i]];
  }

  // 正答の追随
  String? correctLabel;

  if (rawCorrect is int) {
    final origIndex = rawCorrect;
    if (origIndex >= 0 && origIndex < n) {
      // シャッフル後に origIndex がどの newLabel に入ったかを逆引き
      final newPos = idxs.indexOf(origIndex);
      if (newPos >= 0) correctLabel = labels[newPos];
    }
  } else if (rawCorrect is String) {
    // 元がMapでラベル指定、またはListでもラベル文字を渡された場合
    // 可能であれば、'A'.. を index に解釈して追随
    final upper = rawCorrect.trim().toUpperCase();
    final origIndex = _labelToIndex(upper);
    if (origIndex != null && origIndex < n) {
      final newPos = idxs.indexOf(origIndex);
      if (newPos >= 0) correctLabel = labels[newPos];
    } else {
      // 文字列がそのまま本文の場合は、本文一致で追随
      final origText = upper;
      for (var i = 0; i < n; i++) {
        if (list[idxs[i]].toUpperCase() == origText) {
          correctLabel = labels[i];
          break;
        }
      }
    }
  } else if (rawCorrect != null) {
    // 正答が本文そのもの（厳密一致）だった場合
    final correctText = rawCorrect.toString();
    for (var i = 0; i < n; i++) {
      if (list[idxs[i]] == correctText) {
        correctLabel = labels[i];
        break;
      }
    }
  }

  // フォールバック：見つからない場合はとりあえず 'A'
  correctLabel ??= 'A';

  return ShuffledChoices(choices: newMap, correct: correctLabel);
}

List<String> _toList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  if (raw is Map) {
    // ラベル順 A,B,C,D,E... に並べ替えて拾う
    final entries = raw.entries
        .map((e) => MapEntry(e.key.toString().toUpperCase(), e.value.toString()))
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => e.value).where((s) => s.isNotEmpty).toList();
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
// 例: 先頭に1行コメントを追加
// noop: touch for git