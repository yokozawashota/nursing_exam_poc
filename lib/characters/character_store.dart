import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'character.dart';
import 'character_catalog.dart';

/// 選択中キャラを安全に保持（SharedPreferences）
///
/// - 既存画面に影響を与えない独立ストア
/// - まずは「ワン助」を必ず表示できることを優先
class CharacterStore {
  CharacterStore._();
  static final CharacterStore instance = CharacterStore._();

  static const _prefsKey = 'selected_character_id_v1';

  final ValueNotifier<Character> _current =
  ValueNotifier<Character>(CharacterCatalog.wansuke);
  ValueListenable<Character> get currentListenable => _current;

  bool _loaded = false;
  Future<void>? _loadingFuture;

  Future<void> ensureLoaded() {
    _loadingFuture ??= _loadOnce();
    return _loadingFuture!;
  }

  Future<void> _loadOnce() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    _current.value = CharacterCatalog.byId(id);
  }

  Character get current => _current.value;

  Future<void> setCharacter(Character c) async {
    _current.value = c;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, c.id);
  }
}