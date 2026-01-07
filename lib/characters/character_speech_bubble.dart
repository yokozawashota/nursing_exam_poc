// lib/characters/character_speech_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_chat_bubble/bubble_type.dart';
import 'package:flutter_chat_bubble/clippers/chat_bubble_clipper_6.dart';

class CharacterSpeechBubble extends StatelessWidget {
  const CharacterSpeechBubble({
    super.key,
    required this.text,
    this.maxWidth = 240,
  });

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ChatBubble(
        clipper: ChatBubbleClipper6(
          type: BubbleType.sendBubble, // ← 右側にしっぽ
        ),
        alignment: Alignment.bottomRight,
        margin: const EdgeInsets.only(bottom: 6),
        backGroundColor: theme.colorScheme.primary.withOpacity(0.95),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}