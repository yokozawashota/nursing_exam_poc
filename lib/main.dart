// lib/main.dart
import 'package:flutter/material.dart';

import 'theme/app_theme.dart';                 // ← 追加：共通テーマ
import 'screens/question_screen.dart';
import 'screens/score_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/answer_history_screen.dart';
import 'widgets/base_scaffold.dart';
import 'widgets/app_buttons.dart';

void main() {
  runApp(const NurAIApp());
}

class NurAIApp extends StatelessWidget {
  const NurAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NurAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),                 // ← ここだけで全体の見た目を統一
      // darkTheme: AppTheme.dark(),           // （必要になったら用意して切替可）
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'NurAI',
      showBack: false,
      actions: [
        IconButton(
          tooltip: '設定',
          onPressed: () => _go(context, const SettingsScreen()),
          icon: const Icon(Icons.settings),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'メニュー',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            AppButtons.primary(
              label: '問題を解く',
              icon: Icons.menu_book,
              onPressed: () => _go(context, const QuestionScreen()),
            ),
            const SizedBox(height: 12),

            AppButtons.success(
              label: 'スコアを見る',
              icon: Icons.bar_chart,
              onPressed: () => _go(context, const ScoreScreen()),
            ),
            const SizedBox(height: 12),

            AppButtons.neutral(
              label: '解答履歴',
              icon: Icons.history,
              onPressed: () => _go(context, const AnswerHistoryScreen()),
            ),
            const SizedBox(height: 12),

            AppButtons.neutral(
              label: '設定',
              icon: Icons.settings,
              onPressed: () => _go(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}