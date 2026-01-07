// lib/characters/character_speech_store.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'character.dart';
import 'character_speech_key.dart';

class CharacterSpeechStore {
  CharacterSpeechStore._();
  static final instance = CharacterSpeechStore._();

  static const _prefix = 'character_speech_recent_v1';
  static const _maxRecent = 6;

  String _prefsKey(Character c, CharacterSpeechKey key) =>
      '$_prefix:${c.id}:${key.name}';

  Future<List<String>> getRecent({
    required Character character,
    required CharacterSpeechKey key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(character, key));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> pushRecent({
    required Character character,
    required CharacterSpeechKey key,
    required String line,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getRecent(character: character, key: key);

    final next = <String>[line, ...list.where((s) => s != line)];
    if (next.length > _maxRecent) {
      next.removeRange(_maxRecent, next.length);
    }

    await prefs.setString(_prefsKey(character, key), jsonEncode(next));
  }
}