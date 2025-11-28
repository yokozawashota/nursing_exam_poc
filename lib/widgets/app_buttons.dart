// lib/widgets/app_buttons.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 画面共通のボタン群
class AppButtons {
  /// メインのアクション（例：問題を生成 / 保存）
  static Widget primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon ?? Icons.bolt),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2, // ← 影は elevation によって自動生成
            ),
          ),
        );
      },
    );
  }

  /// 成功・確定系（例：保存, 完了）
  static Widget success({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_circle),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.correct,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  /// ニュートラル（例：設定）
  static Widget neutral({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon ?? Icons.settings),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.surface,
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
            ),
          ),
        );
      },
    );
  }
}