// lib/features/ai_analysis/storage/ai_analysis_history.dart

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI分析結果の履歴 1件分
@immutable
class AiAnalysisHistoryEntry {
  final String id;             // 例: epoch_ms文字列
  final DateTime createdAt;    // 分析実行日時
  final String scope;          // 'overall' or 'domain'
  final String targetLabel;    // '全体', '成人看護学' など
  final int totalAnswers;      // 対象となった解答数
  final double accuracy;       // 総合正答率(0.0〜1.0)
  final String body;           // 表示する分析レポート本文

  const AiAnalysisHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.scope,
    required this.targetLabel,
    required this.totalAnswers,
    required this.accuracy,
    required this.body,
  });

  factory AiAnalysisHistoryEntry.fromJson(Map<String, dynamic> j) {
    DateTime _parseTs(dynamic v) {
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
        final asInt = int.tryParse(v);
        if (asInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        }
      }
      return DateTime.now();
    }

    return AiAnalysisHistoryEntry(
      id: (j['id'] ?? '').toString(),
      createdAt: _parseTs(j['createdAt']),
      scope: (j['scope'] ?? 'overall').toString(),
      targetLabel: (j['targetLabel'] ?? '').toString(),
      totalAnswers: (j['totalAnswers'] as num?)?.toInt() ?? 0,
      accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0.0,
      body: (j['body'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'scope': scope,
    'targetLabel': targetLabel,
    'totalAnswers': totalAnswers,
    'accuracy': accuracy,
    'body': body,
  };
}

/// SharedPreferences に保存する履歴管理
class AiAnalysisHistory {
  AiAnalysisHistory._();
  static final AiAnalysisHistory instance = AiAnalysisHistory._();

  static const _storageKey = 'ai_analysis_history_v1';
  static const _maxKeep = 100; // 履歴は最大100件まで

  Future<List<AiAnalysisHistoryEntry>> all() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_storageKey) ?? const <String>[];

    final out = <AiAnalysisHistoryEntry>[];
    for (final s in raw) {
      try {
        final obj = jsonDecode(s);
        if (obj is Map<String, dynamic>) {
          out.add(AiAnalysisHistoryEntry.fromJson(obj));
        } else if (obj is Map) {
          out.add(
              AiAnalysisHistoryEntry.fromJson(Map<String, dynamic>.from(obj)));
        }
      } catch (_) {
        // 壊れたエントリはスキップ
      }
    }

    // 新しい順（先頭が新しい）で保存している想定だが、念のためソート
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> add(AiAnalysisHistoryEntry entry) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_storageKey) ?? <String>[];

    // 先頭に追加
    list.insert(0, jsonEncode(entry.toJson()));

    // 上限を超えた分を切り捨て
    if (list.length > _maxKeep) {
      list.removeRange(_maxKeep, list.length);
    }

    await sp.setStringList(_storageKey, list);
  }

  Future<void> remove(String id) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_storageKey) ?? <String>[];

    list.removeWhere((s) {
      try {
        final obj = jsonDecode(s);
        if (obj is Map) {
          final map = Map<String, dynamic>.from(obj);
          return (map['id'] ?? '').toString() == id;
        }
      } catch (_) {}
      return false;
    });

    await sp.setStringList(_storageKey, list);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_storageKey);
  }
}