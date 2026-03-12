// lib/features/practice/utils/practice_result_formatter.dart

class PracticeResultFormatter {
  const PracticeResultFormatter._();

  /// explanation の整形
  ///
  /// - select_incorrect のときだけ、
  ///   「選択肢CとDが誤った記述です。」などの一文を先頭に挿入（または置換）して
  ///   correctAnswers と必ず整合するようにする。
  static String normalizeExplanation({
    required String explanation,
    required List<String> correctAnswers,
    required String questionKind,
  }) {
    final trimmed = explanation.trim();
    if (trimmed.isEmpty) return '';

    if (questionKind != 'select_incorrect') {
      return trimmed;
    }

    final labels = correctAnswers
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (labels.isEmpty) return trimmed;

    final joined = labelsToJoined(labels);
    final head = '選択肢$joinedが誤った記述です。';

    final firstPeriodIndex = trimmed.indexOf('。');
    if (firstPeriodIndex >= 0) {
      final firstSentence = trimmed.substring(0, firstPeriodIndex + 1);
      final rest = trimmed.substring(firstPeriodIndex + 1).trimLeft();

      final isIncorrectLeadSentence =
          firstSentence.contains('選択肢') &&
              (firstSentence.contains('誤った') ||
                  firstSentence.contains('誤り') ||
                  firstSentence.contains('誤っている'));

      if (isIncorrectLeadSentence) {
        return rest.isEmpty ? head : '$head$rest';
      }

      return '$head$trimmed';
    }

    return '$head$trimmed';
  }

  /// ラベル配列を「A」「AとB」「A、BとC」形式に連結
  static String labelsToJoined(List<String> labels) {
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}と${labels[1]}';

    final head = labels.sublist(0, labels.length - 1).join('、');
    return '$headと${labels.last}';
  }
}