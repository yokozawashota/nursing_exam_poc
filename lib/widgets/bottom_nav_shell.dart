// lib/widgets/bottom_nav_shell.dart
import 'package:flutter/material.dart';

import '../screens/question_screen.dart';
import '../screens/score_screen.dart';
import '../screens/answer_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/notice_list_screen.dart';
import '../screens/mock_exam_config_screen.dart';
import '../screens/ai_analysis_screen.dart';
import '../screens/past_exam/past_exam_year_list_screen.dart';

import '../theme/app_theme.dart';
import '../services/notice_service.dart';
import '../services/notice_prefs.dart';
import '../models/notice.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 2;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = <Widget>[
      const AiAnalysisScreen(),           // 0: 学習分析
      const ScoreScreen(),               // 1: スコア
      _HomeTab(onSelectTab: _setIndex),  // 2: ホーム
      const AnswerHistoryScreen(),       // 3: 履歴
      const SettingsScreen(),            // 4: 設定
    ];
  }

  void _setIndex(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final navTheme = Theme.of(context).bottomNavigationBarTheme;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),

      // ==== 中央の大きいホームボタン ====
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: 66,
          height: 66,
          child: FloatingActionButton(
            onPressed: () => _setIndex(2),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 4,
            child: const Icon(Icons.home_rounded, size: 30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ==== 下部ナビバー ====
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        elevation: navTheme.elevation ?? 8,
        color: navTheme.backgroundColor ?? Colors.white,
        height: 70,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // ★ 左端タブ：学習分析（AI分析）
              _navItem(context, Icons.auto_awesome_rounded, '学習分析', 0),
              _navItem(context, Icons.bar_chart_rounded, 'スコア', 1),
              const Spacer(),
              _navItem(context, Icons.history_rounded, '履歴', 3),
              _navItem(context, Icons.settings_rounded, '設定', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int idx) {
    final cs = Theme.of(context).colorScheme;
    final navTheme = Theme.of(context).bottomNavigationBarTheme;

    final selected = idx == _index;
    final selectedColor = navTheme.selectedItemColor ?? cs.primary;
    final unselectedColor = navTheme.unselectedItemColor ?? Colors.black54;

    return Expanded(
      child: InkResponse(
        radius: 30,
        onTap: () => _setIndex(idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? selectedColor : unselectedColor,
              size: selected ? 26 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? selectedColor : unselectedColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================
///          ホームタブ
/// =============================
class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==== ヘッダー（左：タイトル、右：通知ベル）====
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NurAI',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '看護師国家試験トレーニング',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // ==== 通知ベル（未読バッジ付き）====
                  FutureBuilder<Notice?>(
                    future: NoticeService.latest(),
                    builder: (context, snap) {
                      return FutureBuilder<int>(
                        future: NoticeService.unreadCount(),
                        builder: (context, unreadSnap) {
                          final unread = unreadSnap.data ?? 0;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 30,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const NoticeListScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unread.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==== 最新お知らせバナー（NEW対応） ====
              FutureBuilder<Notice?>(
                future: NoticeService.latest(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 24);
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'お知らせの読み込みに失敗しました',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red),
                      ),
                    );
                  }

                  final latest = snap.data;
                  if (latest == null) return const SizedBox(height: 24);

                  return Column(
                    children: [
                      _NoticeBanner(
                        notice: latest,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NoticeListScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // ==== メインCTA（問題生成）====
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: AppStyles.ctaButton(context),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('問題を生成する'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuestionScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ==== セカンダリCTA（模試モード）====
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: AppStyles.ctaButton(context).copyWith(
                    minimumSize:
                    MaterialStateProperty.all(const Size.fromHeight(52)),
                  ),
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: const Text('模試モードを始める'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MockExamConfigScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ==== 過去問CTA（第113回 必修 午前）====
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: AppStyles.outlinedButton,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('年度別過去問'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PastExamYearListScreen(),
                    ),
                  );
                },
              ),
            ),

              const SizedBox(height: 20),

              // ==== スコア & 解答履歴 ====
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppStyles.outlinedButton,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('スコア'),
                      onPressed: () => onSelectTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppStyles.outlinedButton,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('解答履歴'),
                      onPressed: () => onSelectTab(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================
///   ホーム画面の「最新お知らせバナー」
/// =============================
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.notice,
    required this.onTap,
  });

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<Set<String>>(
      future: NoticePrefs.getReadIds(),
      builder: (context, snap) {
        final readIds = snap.data ?? {};
        final isNew = !readIds.contains(notice.id);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.campaign_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),

                // ===== テキスト =====
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==== タイトル + NEW ====
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notice.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNew)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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

                      const SizedBox(height: 2),

                      // 要約
                      Text(
                        notice.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}