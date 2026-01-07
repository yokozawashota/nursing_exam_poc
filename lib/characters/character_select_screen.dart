import 'package:flutter/material.dart';

import 'character_catalog.dart';
import 'character_store.dart';

class CharacterSelectScreen extends StatelessWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('キャラクター選択'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ...CharacterCatalog.all.map((c) {
            final isSelected = CharacterStore.instance.current.id == c.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: theme.colorScheme.surface,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    c.assetPath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded),
                  ),
                ),
                title: Text(c.name, style: theme.textTheme.titleMedium),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await CharacterStore.instance.setCharacter(c);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}