import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 正解インデックスを均等に回すための「袋方式」ピッカー。
/// 例：長さ4なら [0,1,2,3] をシャッフルして先頭から1つずつ消費。尽きたら再充填。
class BalancedIndexPicker {
  /// [length] は choices の数（通常4）。長さごとに独立した袋を持つ。
  static Future<int> next({int length = 4}) async {
    assert(length > 0);
    final prefs = await SharedPreferences.getInstance();
    final key = 'balanced_idx_bag::$length';
    final rnd = Random();

    List<String> bagStr = prefs.getStringList(key) ?? <String>[];
    List<int> bag = bagStr.map((e) => int.tryParse(e) ?? -1).where((e) => e >= 0).toList();

    final valid = bag.isNotEmpty &&
        bag.every((e) => e >= 0 && e < length) &&
        bag.toSet().length <= length;

    if (!valid || bag.isEmpty) {
      bag = List<int>.generate(length, (i) => i)..shuffle(rnd);
    }

    final picked = bag.removeAt(0);
    await prefs.setStringList(key, bag.map((e) => e.toString()).toList());
    return picked;
  }
}