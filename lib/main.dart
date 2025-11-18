// lib/main.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav_shell.dart';

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
      theme: AppTheme.light(),
      home: const BottomNavShell(), // ← 常時ボトムナビ付き
    );
  }
}