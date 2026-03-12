// lib/questioning/services/topic_picker.dart

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// 3階層対応の袋方式ローテータ
/// - 同じ「分野>大項目>中項目」内では、小項目を引き切るまで重複しにくい
/// - 中項目未選択の時は「分野>大項目」内の中項目を均等ローテーション
class TopicPicker {
  TopicPicker._();

  /// 小項目ピック（分野>大項目>中項目）
  static Future<String> pickTopic({
    required String domain,
    required String major,
    required String mid,
    required List<String> topics,
  }) {
    return _nextFromBag('topic::$domain::$major::$mid', topics);
  }

  /// 中項目ピック（一般/状況設定：UI未選択時）
  static Future<String> pickMidForMajor({
    required String domain,
    required String major,
    required List<String> mids,
  }) {
    return _nextFromBag('general-mid::$domain::$major', mids);
  }

  /// 必修：大項目から中項目ピック（従来互換）
  static Future<String> pickHisshuMidForMajor(String major, List<String> mids) {
    return _nextFromBag('hisshu-mid::$major', mids);
  }

  /// 任意の袋キーで items を均等ローテーション
  static Future<String> _nextFromBag(String key, List<String> items) async {
    if (items.isEmpty) {
      throw StateError('TopicPicker: items is empty for key=$key');
    }
    final prefs = await SharedPreferences.getInstance();
    final rnd = Random();

    // 保存済み袋
    final raw = prefs.getStringList(key) ?? const <String>[];
    // 現行リストと突き合わせ（定義変更に強い）
    final inBag = raw.where((e) => items.contains(e)).toList();

    List<String> bag = inBag.isEmpty ? (List<String>.from(items)..shuffle(rnd)) : inBag;

    final picked = bag.removeAt(0);
    await prefs.setStringList(key, bag);
    return picked;
  }

  /// 設定画面から呼ぶ想定のリセット
  static Future<void> resetAll({List<String> keys = const <String>[]}) async {
    final prefs = await SharedPreferences.getInstance();
    if (keys.isEmpty) {
      for (final k in prefs.getKeys()) {
        if (k.startsWith('topic::') || k.startsWith('general-mid::') || k.startsWith('hisshu-mid::')) {
          await prefs.remove(k);
        }
      }
    } else {
      for (final k in keys) {
        await prefs.remove(k);
      }
    }
  }
}