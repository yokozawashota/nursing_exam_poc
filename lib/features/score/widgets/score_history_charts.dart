// lib/features/score/widgets/score_history_charts.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../history/models/history_models.dart';
import '../services/score_history_stats.dart';
import '../../../shared/theme/app_theme.dart';

/// シンプルな横棒グラフ（依存0）
///
/// items の value は 0.0〜1.0 を想定する。
/// 例: [{label: '一般問題', value: 0.62}, ...]
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.items,
    this.title,
    this.barHeight = 18,
    this.maxItems = 6,
  });

  final List<_BarItem> items;
  final String? title;
  final double barHeight;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final visible =
    (maxItems <= 0) ? const <_BarItem>[] : items.take(maxItems).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.12),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...visible
              .map((e) => _BarRow(item: e, barHeight: barHeight))
              .toList(),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.item,
    required this.barHeight,
  });

  final _BarItem item;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final safe = item.value.isNaN ? 0.0 : item.value;
    final clamped = safe.clamp(0.0, 1.0);
    final pct = (clamped * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // ラベル
          SizedBox(
            width: 120,
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // バー
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: barHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ベースバー
                    Container(
                      color: AppColors.primaryLight.withOpacity(0.6),
                    ),

                    // 実値バー
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: clamped,
                      child: Container(
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 数値
          SizedBox(
            width: 50,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;

  const _BarItem(this.label, this.value);
}

/// 後方互換ヘルパー
///
/// 正答率マップ
/// `{"一般問題": {"total":10, "correct":7}, ...}`
/// を MiniBarChart 用 items に変換する。
List<_BarItem> buildBarItemsFromStatMap(Map<String, dynamic> source) {
  final List<_BarItem> out = [];

  source.forEach((k, v) {
    if (v is Map) {
      final total = (v['total'] as num?)?.toInt() ?? 0;
      final correct = (v['correct'] as num?)?.toInt() ?? 0;
      final rate = total == 0 ? 0.0 : (correct / total);
      out.add(_BarItem(k.toString(), rate));
    }
  });

  // 正答率が高い順
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}

/// DomainSummary（型）→ グラフ用アイテム
List<_BarItem> buildBarItemsFromDomainSummaries(
    List<DomainSummary> summaries,
    ) {
  final items = summaries
      .map((s) => _BarItem(s.domain, s.accuracy))
      .toList(growable: false);

  items.sort((a, b) => b.value.compareTo(a.value));
  return items;
}

/// HistoryRecord のリストから直接グラフ用アイテムを構築する。
///
/// 内部で `HistoryStats.domainSummaries` を使用する。
List<_BarItem> buildBarItemsFromHistory(List<HistoryRecord> records) {
  final summaries = HistoryStats.domainSummaries(records);
  return buildBarItemsFromDomainSummaries(summaries);
}