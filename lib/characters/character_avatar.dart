import 'package:flutter/material.dart';

import 'character.dart';

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    this.size = 140,
    this.onTap,
    this.onLongPress,
  });

  final Character character;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // 画像だけ（背景なし）
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          character.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.pets_rounded,
            size: size * 0.7,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}