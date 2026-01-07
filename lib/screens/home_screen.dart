import 'package:flutter/material.dart';

import '../characters/character_store.dart';
import '../characters/character_avatar.dart';
import '../characters/character_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔥 HomeScreen build called');
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: CharacterStore.instance.ensureLoaded(),
      builder: (context, snap) {
        return Container(
          alignment: Alignment.center,
          color: cs.surfaceContainerLowest,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // ============================
              // 🔍【確認用】assets直読みテスト
              // ============================
              Column(
                children: [
                  const Text(
                    '【確認用：assets直読み】',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/characters/wansuke.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ============================
              // 🐶 ワン助（本番ルート）
              // ============================
              ValueListenableBuilder(
                valueListenable: CharacterStore.instance.currentListenable,
                builder: (context, character, _) {
                  return CharacterAvatar(
                    character: character,
                    size: 84,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CharacterSelectScreen(),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 18),

              Text(
                'ホーム',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}