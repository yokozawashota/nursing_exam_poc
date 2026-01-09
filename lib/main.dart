// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nursing_exam_poc/app/bottom_nav_shell.dart';
import 'package:nursing_exam_poc/features/past_exam/screens/past_exam_home_screen.dart';
import 'package:nursing_exam_poc/shared/theme/app_theme.dart';

Future<void> main() async {
  // runApp の前に初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 画面向きを「縦（上向き）」に固定（逆さNG）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const NurAIApp());
}

class NurAIApp extends StatelessWidget {
  const NurAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NurAI',
      debugShowCheckedModeBanner: false,

      // 新しいテーマ構造（buildAppTheme を使用）
      theme: buildAppTheme(),

      // ★ named route で過去問モードに飛べるようにしておく
      routes: {
        '/past-exam': (_) => const PastExamHomeScreen(),
      },

      // ← 常時ボトムナビ付き構成そのまま
      home: const BottomNavShell(),
    );
  }
}