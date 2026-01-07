// lib/characters/character_speech_controller.dart
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'character.dart';
import 'character_speech_key.dart';
import 'character_speech_provider.dart';
import 'character_speech_store.dart';

class CharacterSpeechController {
  CharacterSpeechController._();
  static final instance = CharacterSpeechController._();

  final ValueNotifier<String?> currentSpeech = ValueNotifier<String?>(null);

  final _rng = Random();

  /// HUDタップなどから呼ぶ
  Future<void> show({
    required Character character,
    required CharacterSpeechKey key,
  }) async {
    final candidates = CharacterSpeechProvider.lines(
      key,
      character: character,
      // ここで DateTime.now() は Provider 側で補完しているので渡さなくてOK
    );

    if (candidates.isEmpty) {
      currentSpeech.value = null;
      return;
    }

    final recent = await CharacterSpeechStore.instance.getRecent(
      character: character,
      key: key,
    );

    // 直近と被らない候補を優先
    final fresh = candidates.where((s) => !recent.contains(s)).toList();
    final pool = fresh.isNotEmpty ? fresh : candidates;

    final next = pool[_rng.nextInt(pool.length)];
    currentSpeech.value = next;

    await CharacterSpeechStore.instance.pushRecent(
      character: character,
      key: key,
      line: next,
    );
  }

  void clear() {
    currentSpeech.value = null;
  }
}