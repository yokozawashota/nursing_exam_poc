// lib/widgets/bottom_nav_shell.dart
import 'package:flutter/material.dart';

import '../screens/question_screen.dart';
import '../screens/score_screen.dart';
import '../screens/answer_history_screen.dart';
import '../screens/settings_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 2; // 中央(Home) を初期表示

  late final List<Widget> _pages = const [
    _ComingSoonTab(),          // 0: テスト（枠だけ）
    ScoreScreen(),             // 1: スコア
    _HomeTab(),                // 2: ホーム（CTA付き）
    AnswerHistoryScreen(),     // 3: 履歴
    SettingsScreen(),          // 4: 設定
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _pages),
      ),

      // 中央ホームFAB（見切れ防止に下マージン＋底上げ）
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10), // ← 下に少し余白
        child: SizedBox(
          width: 66,
          height: 66,
          child: FloatingActionButton(
            elevation: 6,
            onPressed: () => setState(() => _index = 2),
            child: const Icon(Icons.home_rounded, size: 30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// ホームタブ（メインCTA：問題を生成する）
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        // 下のナビと被らないよう余白を大きめに
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // 1. メインCTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    '問題を生成する',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QuestionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 2. サブCTA（任意）
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('スコア'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScoreScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('解答履歴'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AnswerHistoryScreen()),
                      ),
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

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('テスト機能は準備中です'));
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,    // ← ノッチ余白を広げてFABと干渉しにくく
      height: 74,         // ← 高さを上げて見切れ対策
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _item(icon: Icons.science_rounded, label: 'テスト', idx: 0),
              _item(icon: Icons.bar_chart_rounded, label: 'スコア', idx: 1),
              const Spacer(),
              _item(icon: Icons.history_rounded, label: '履歴', idx: 3),
              _item(icon: Icons.settings_rounded, label: '設定', idx: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({required IconData icon, required String label, required int idx}) {
    final selected = (currentIndex == idx);
    final color = selected ? Colors.blueAccent : null;
    return Expanded(
      child: InkResponse(
        onTap: () => onTap(idx),
        radius: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: selected ? 26 : 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}