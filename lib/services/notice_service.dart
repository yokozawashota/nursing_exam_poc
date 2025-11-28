// lib/services/notice_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/notice.dart';
import 'notice_prefs.dart';

class NoticeService {
  static const String _assetPath = 'assets/notices.json';
  static List<Notice>? _cache;

  /// 全お知らせ（新→古）
  static Future<List<Notice>> all() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString(_assetPath);

    final list = json.decode(jsonStr) as List;
    final notices = list.map((e) {
      try {
        return Notice.fromJson(e);
      } catch (_) {
        return null;
      }
    }).whereType<Notice>().toList();

    notices.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    _cache = notices;
    return notices;
  }

  /// 最新のお知らせ
  static Future<Notice?> latest() async {
    final allItems = await all();
    if (allItems.isEmpty) return null;
    return allItems.first;
  }

  /// 未読件数を返す（readIds で判定）
  static Future<int> unreadCount() async {
    final notices = await all();
    final readIds = await NoticePrefs.getReadIds();
    return notices.where((n) => !readIds.contains(n.id)).length;
  }
}