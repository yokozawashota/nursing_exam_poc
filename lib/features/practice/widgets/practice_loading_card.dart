// lib/features/practice/widgets/practice_loading_card.dart

import 'package:flutter/material.dart';

class PracticeLoadingCard extends StatelessWidget {
  const PracticeLoadingCard({
    super.key,
    required this.message,
    required this.progress,
  });

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Text('$percent%'),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '※通信状況やモデルにより数秒〜数十秒かかることがあります',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}