// lib/screens/notice_list_screen.dart
import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../services/notice_service.dart';
import '../services/notice_prefs.dart';
import '../models/notice.dart';
import '../theme/app_theme.dart';
import 'notice_detail_screen.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  late Future<List<Notice>> _futureNotices;
  late Future<Set<String>> _futureReadIds;

  @override
  void initState() {
    super.initState();
    // 一覧を開いた「だけ」では既読にしない
    _futureNotices = NoticeService.all();
    _futureReadIds = NoticePrefs.getReadIds();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'お知らせ',
      showBack: true,
      body: FutureBuilder<List<Notice>>(
        future: _futureNotices,
        builder: (context, snapNotices) {
          if (snapNotices.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapNotices.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('お知らせの読み込みに失敗しました: ${snapNotices.error}'),
              ),
            );
          }

          final notices = snapNotices.data ?? [];
          if (notices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('現在表示できるお知らせはありません。'),
              ),
            );
          }

          // 既読ID取得
          return FutureBuilder<Set<String>>(
            future: _futureReadIds,
            builder: (context, snapRead) {
              if (snapRead.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final readIds = snapRead.data ?? {};

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: notices.length,
                itemBuilder: (context, i) {
                  final n = notices[i];
                  final isRead = readIds.contains(n.id);

                  return _NoticeTile(
                    notice: n,
                    isRead: isRead,
                    onOpened: () async {
                      await NoticePrefs.markAsRead(n.id);
                      setState(() {
                        _futureReadIds = NoticePrefs.getReadIds(); // 更新
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.notice,
    required this.isRead,
    required this.onOpened,
  });

  final Notice notice;
  final bool isRead;
  final Future<void> Function() onOpened;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // ⭐ 詳細画面へ遷移
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoticeDetailScreen(notice: n),
            ),
          );

          // ⭐ 戻ってきたら既読更新
          await onOpened();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.campaign_rounded,
                size: 22,
                color: n.pinned ? AppColors.primary : Colors.grey[500],
              ),
              const SizedBox(width: 10),

              // ---- 文章 ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== タイトル行（NEW バッジ付き） =====
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // 本文要約
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 日付
                    Text(
                      n.dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}