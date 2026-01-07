import 'character.dart';

/// キャラクター一覧（今はワン助1体だけ）
/// 追加していく場合もここに集約
class CharacterCatalog {
  static const String defaultId = 'wansuke';

  static const Character wansuke = Character(
    id: 'wansuke',
    name: 'ワン助',
    assetPath: 'assets/characters/wansuke.png',
  );
  static const Character nacco = Character(
    id: 'nacco',
    name: 'ナッコ',
    assetPath: 'assets/characters/nacco.png',
  );
  static const Character nayu = Character(
    id: 'nayu',
    name: 'ナーユ',
    assetPath: 'assets/characters/nayu.png',
  );

  static const List<Character> all = [
    wansuke,
    nacco,
    nayu,
  ];

  static Character byId(String? id) {
    if (id == null || id.trim().isEmpty) return wansuke;
    return all.firstWhere(
          (c) => c.id == id,
      orElse: () => wansuke,
    );
  }
}