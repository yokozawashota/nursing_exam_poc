// lib/features/notice/screens/notice_detail_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../../../shared/theme/app_theme.dart';

import '../models/notice.dart';
import '../services/notice_prefs.dart';

class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({super.key, required this.notice});

  final Notice notice;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();

    // ⭐ 詳細画面を開いた瞬間、このお知らせだけ既読にする
    NoticePrefs.markAsRead(widget.notice.id);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final theme = Theme.of(context);

    return BaseScaffold(
      title: 'お知らせ詳細',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 タイトル
            Text(
              n.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 発行日表示
            Text(
              n.dateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // 🔹 本文
            Text(
              n.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),

            // 🔹 ピン表示（重要なお知らせ）
            if (n.pinned)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '重要なお知らせ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}