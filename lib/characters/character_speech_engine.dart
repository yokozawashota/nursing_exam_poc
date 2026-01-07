// lib/characters/character_speech_engine.dart
import 'dart:math';

class CharacterSpeechEngine {
  CharacterSpeechEngine._();

  static final _rng = Random();

  /// candidates から「直近の recent を避けて」選ぶ
  /// - 全部 recent なら candidates からランダム
  static String pick({
    required List<String> candidates,
    required List<String> recent,
  }) {
    if (candidates.isEmpty) return '';

    final recentSet = recent.toSet();

    final pool = candidates.where((s) => !recentSet.contains(s)).toList();
    final list = pool.isNotEmpty ? pool : candidates;

    return list[_rng.nextInt(list.length)];
  }
}