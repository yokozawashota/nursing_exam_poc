class DebugUtils {
  static String firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    return (t.length <= maxChars) ? t : '${t.substring(0, maxChars)}...';
  }
}