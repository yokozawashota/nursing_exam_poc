// lib/models/notice.dart
import 'package:flutter/foundation.dart';

/// アプリ内のお知らせ情報
class Notice {
  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final bool pinned; // 重要なお知らせかどうか

  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.pinned = false,
  });

  /// JSON から Notice を生成
  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      pinned: json['pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'publishedAt': publishedAt.toIso8601String(),
      'pinned': pinned,
    };
  }

  /// 日付表示用（例: 2025/11/19）
  String get dateLabel {
    final y = publishedAt.year.toString().padLeft(4, '0');
    final m = publishedAt.month.toString().padLeft(2, '0');
    final d = publishedAt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }
}