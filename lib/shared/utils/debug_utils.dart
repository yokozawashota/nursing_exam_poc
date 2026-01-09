// lib/shared/utils/debug_utils.dart
import 'package:characters/characters.dart';

class DebugUtils {
  /// 1行化して先頭 maxChars だけ切り出す（サロゲートペアや結合文字も安全）。
  static String firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    final chars = t.characters;
    if (chars.length <= maxChars) return t;
    return '${chars.take(maxChars)}...';
  }
}