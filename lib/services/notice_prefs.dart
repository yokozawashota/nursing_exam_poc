// lib/services/notice_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

class NoticePrefs {
  static const _keyReadIds = 'notice_read_ids';

  /// 既読ID一覧を取得
  static Future<Set<String>> getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyReadIds) ?? <String>[];
    return list.toSet();
  }

  /// 指定した noticeId を既読に追加
  static Future<void> markAsRead(String noticeId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyReadIds) ?? <String>[];

    if (!list.contains(noticeId)) {
      list.add(noticeId);
      await prefs.setStringList(_keyReadIds, list);
    }
  }

  /// 全既読クリア（テスト用）
  static Future<void> clearReads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyReadIds);
  }
}