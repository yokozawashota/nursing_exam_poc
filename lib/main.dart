// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:nursing_exam_poc/app/bottom_nav_shell.dart';
import 'package:nursing_exam_poc/features/past_exam/screens/past_exam_home_screen.dart';
import 'package:nursing_exam_poc/shared/theme/app_theme.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // ネイティブスプラッシュを保持
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 少しだけ表示時間を伸ばす
  await Future.delayed(const Duration(milliseconds: 1000));

  // ネイティブスプラッシュ解除
  FlutterNativeSplash.remove();

  runApp(const NurAIApp());
}

class NurAIApp extends StatelessWidget {
  const NurAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NurAI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routes: {
        '/past-exam': (_) => const PastExamHomeScreen(),
      },
      home: const BottomNavShell(),
    );
  }
}