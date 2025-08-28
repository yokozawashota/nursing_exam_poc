import 'package:flutter/material.dart';

/// シンプルな横棒グラフ（依存0）
/// items: [{label: '一般問題', value: 0.62}, ...] の value は 0.0〜1.0
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
    final visible = items.take(maxItems).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          ...visible.map((e) => _BarRow(item: e, barHeight: barHeight)).toList(),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.item, required this.barHeight});
  final _BarItem item;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final pct = (item.value.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
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
              style: const TextStyle(color: Colors.black87),
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
                    Container(color: const Color(0xFFF1EAF5)), // ベース
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: item.value.clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFF5C6BC0)), // インディゴ
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
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
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
  final double value; // 0.0〜1.0
  _BarItem(this.label, this.value);
}

/// ヘルパー: 正答率のマップ（{"一般問題": {"total":10, "correct":7}, ...}）を
/// MiniBarChart の items に変換
List<_BarItem> buildBarItemsFromStatMap(Map<String, dynamic> source) {
  final List<_BarItem> out = [];
  source.forEach((k, v) {
    if (v is Map) {
      final total = (v['total'] ?? 0) as int;
      final correct = (v['correct'] ?? 0) as int;
      final rate = total == 0 ? 0.0 : (correct / total);
      out.add(_BarItem(k, rate));
    }
  });
  // 正答率が高い順
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}