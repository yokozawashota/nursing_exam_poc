import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 偏りを抑える「袋方式」ピッカー。
/// - 袋（シャッフル済みのリスト）から1件ずつ取り出し、尽きたら補充して再シャッフル。
/// - スコープごとに袋を分け、端末に保存して継続性を担保。
class TopicPicker {
  /// 小項目用（一般・必修どちらでもOK）：(category, subcategory) スコープ
  static Future<String> pick(String category, String subcategory, List<String> pool) async {
    final scope = 'topic::$category::$subcategory';
    return _pickFromPool(scope, pool);
  }

  /// 必修：大項目ごとに「中項目」を内部選定するためのピッカー
  static Future<String> pickHisshuMidForMajor(String major, List<String> mids) async {
    final scope = 'mid::必修::$major';
    return _pickFromPool(scope, mids);
  }

  // 共通実装
  static Future<String> _pickFromPool(String scope, List<String> pool) async {
    final prefs = await SharedPreferences.getInstance();
    final bagKey = 'bag::$scope';
    final rnd = Random();

    List<String> bag = prefs.getStringList(bagKey) ?? <String>[];

    // 袋が空 or 不整合（プール差分あり）の場合は再充填
    final setBag = bag.toSet();
    final setPool = pool.toSet();
    final inconsistent = setBag.difference(setPool).isNotEmpty || setPool.difference(setBag).isNotEmpty;
    if (bag.isEmpty || inconsistent) {
      bag = List<String>.from(pool);
      bag.shuffle(rnd);
    }

    final choice = bag.first;
    bag.removeAt(0);
    await prefs.setStringList(bagKey, bag);
    return choice;
  }
}