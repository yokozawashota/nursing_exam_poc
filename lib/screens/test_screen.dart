// lib/screens/test_screen.dart
import 'package:flutter/material.dart';
class TestScreen extends StatelessWidget {
  const TestScreen({super.key});
  @override
  Widget build(BuildContext context) => _label(context, 'テスト');
}
Widget _label(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.surfaceContainerLowest,
    alignment: Alignment.center,
    child: Text(text,
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.primary),
    ),
  );
}