// lib/characters/character_hud_anchor.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'character.dart';
import 'character_avatar.dart';
import 'character_select_screen.dart';
import 'character_speech_bubble.dart';
import 'character_speech_controller.dart';
import 'character_speech_key.dart';
import 'character_store.dart';

/// Character HUD anchor
///
/// Spec:
/// - Tap: show speech bubble (auto hide)
/// - Long press: open character select
/// - Bubble is shown by Overlay and positioned by bubbleInset (not tied to character size/pos)
/// - Hit test area is fixed to size x size
class CharacterHudAnchor extends StatefulWidget {
  const CharacterHudAnchor({
    super.key,
    this.size = 140,
    this.padding = EdgeInsets.zero,

    // BottomNavShell etc. should pass only a key (no raw text)
    this.speechKey = CharacterSpeechKey.home,

    // Bubble
    this.bubbleMaxWidth = 240,
    this.bubbleDuration = const Duration(seconds: 3),

    /// Bubble position (easy to tweak with left/bottom)
    this.bubbleInset = const EdgeInsets.only(left: 18, bottom: 200),
  });

  final double size;
  final EdgeInsets padding;

  final CharacterSpeechKey speechKey;

  final double bubbleMaxWidth;
  final Duration bubbleDuration;
  final EdgeInsets bubbleInset;

  @override
  State<CharacterHudAnchor> createState() => _CharacterHudAnchorState();
}

class _CharacterHudAnchorState extends State<CharacterHudAnchor> {
  OverlayEntry? _entry;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeBubble();
    super.dispose();
  }

  void _removeBubble() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _showBubble(Character character) async {
    debugPrint('HUD TAP');

    // 1) Ask controller to pick & set currentSpeech
    await CharacterSpeechController.instance.show(
      character: character,
      key: widget.speechKey,
    );

    // 2) Read the picked line
    final text = CharacterSpeechController.instance.currentSpeech.value;
    if (text == null || text.trim().isEmpty) {
      _hideTimer?.cancel();
      _removeBubble();
      return;
    }

    // 3) Reset existing bubble
    _hideTimer?.cancel();
    _removeBubble();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // 4) Show overlay bubble
    _entry = OverlayEntry(
      builder: (_) {
        // Positioned must be direct child of Stack (avoid ParentDataWidget error)
        return Stack(
          children: [
            Positioned(
              left: widget.bubbleInset.left,
              bottom: widget.bubbleInset.bottom,
              child: IgnorePointer(
                ignoring: true,
                child: SafeArea(
                  child: CharacterSpeechBubble(
                    text: text,
                    maxWidth: widget.bubbleMaxWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);

    // 5) Auto hide
    _hideTimer = Timer(widget.bubbleDuration, () {
      _removeBubble();
      CharacterSpeechController.instance.clear();
    });
  }

  Future<void> _openCharacterSelect() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CharacterSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: CharacterStore.instance.ensureLoaded(),
      builder: (context, snap) {
        return Padding(
          padding: widget.padding,
          child: ValueListenableBuilder(
            valueListenable: CharacterStore.instance.currentListenable,
            builder: (context, Character character, _) {
              // Hit test area is fixed to size x size
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild, // don't catch taps in empty area
                  onTap: () => _showBubble(character),
                  onLongPress: _openCharacterSelect,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: CharacterAvatar(
                      character: character,
                      size: widget.size,
                      onTap: null, // handled by GestureDetector
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}