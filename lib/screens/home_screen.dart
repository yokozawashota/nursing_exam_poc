// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => _label(context, 'ホーム');
}
Widget _label(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    alignment: Alignment.center,
    color: cs.surfaceContainerLowest,
    child: Text(text, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.primary)),
  );
}