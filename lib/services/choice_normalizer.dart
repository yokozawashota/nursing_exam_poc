// lib/services/choice_normalizer.dart
//
// モデルが返す JSON から choices と正答を正規化するユーティリティ。
// QuestionService 以外からも再利用できるよう公開クラスで提供。
class ChoiceItem {
  final String text;
  final bool isCorrect;
  final String? rationale;
  ChoiceItem({required this.text, required this.isCorrect, this.rationale});
}

class NormalizedChoices {
  final List<ChoiceItem> items;
  NormalizedChoices(this.items);
}

class ChoiceNormalizer {
  /// JSON から choices と正答を正規化（内部形式：リスト＋ isCorrect＋ rationale）
  static NormalizedChoices normalize(Map<String, dynamic> json) {
    final dynamic rawChoices = json['choices'];

    // rationales は A-D マップ or 配列 or インデックス・マップかもしれないので柔軟に扱う
    final dynamic rawRationales =
        json['rationales'] ?? json['reasons'] ?? json['rationale'];

    // 正答マーカー抽出
    final int? idxFromNum =
    _asInt(json['correctIndex'] ?? json['answer_index'] ?? json['answerIndex']);
    final String letterFromJson =
    (json['correct'] ?? json['correctLetter'] ?? json['answer_key'] ?? json['answer'] ?? '')
        .toString()
        .trim();

    if (rawChoices is List) {
      // 例：["a","b","c","d"]
      final list =
      rawChoices.map((e) => (e ?? '').toString()).where((s) => s.isNotEmpty).toList();
      // 2〜4 要素に丸める（多すぎる分は切り捨て）
      final limited = list.length > 4 ? list.take(4).toList() : list;

      // インデックスの確定
      int correctIdx = 0;
      if (idxFromNum != null && idxFromNum >= 0 && idxFromNum < limited.length) {
        correctIdx = idxFromNum;
      } else {
        final idxFromLetter = _letterToIndex(letterFromJson);
        if (idxFromLetter != null && idxFromLetter >= 0 && idxFromLetter < limited.length) {
          correctIdx = idxFromLetter;
        } else {
          // モデルが返さない場合は 0 を正答として受け取り、あとでシャッフルで位置を均等化
          correctIdx = 0;
        }
      }

      // ラショナーレの取り出し（配列 or A-D or インデックス）
      final rationalsByIndex = _extractRationalesByIndex(rawRationales, limited.length);

      final items = <ChoiceItem>[];
      for (var i = 0; i < limited.length; i++) {
        items.add(ChoiceItem(
          text: limited[i],
          isCorrect: i == correctIdx,
          rationale: rationalsByIndex[i],
        ));
      }
      return NormalizedChoices(items);
    }

    if (rawChoices is Map) {
      // 例：{"A":"a","B":"b","C":"c","D":"d"}
      final order = ['A', 'B', 'C', 'D', 'E', 'F'];
      final entries = <MapEntry<String, String>>[];
      for (final k in order) {
        final v = rawChoices[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.trim().isEmpty) continue;
        entries.add(MapEntry(k, s));
      }
      // 2〜4件に制限
      final limited = entries.take(4).toList();

      // 正答：数値 or 文字
      int correctIdx = 0;
      if (idxFromNum != null && idxFromNum >= 0 && idxFromNum < limited.length) {
        correctIdx = idxFromNum;
      } else {
        final idxFromLetter = _letterToIndex(letterFromJson);
        if (idxFromLetter != null && idxFromLetter >= 0 && idxFromLetter < limited.length) {
          correctIdx = idxFromLetter;
        } else {
          correctIdx = 0;
        }
      }

      // ラショナーレ取得（A-D マップ基準で受け取り → インデックスへ）
      final rationalsByIndex =
      _extractRationalesByIndexFromLetterMap(rawRationales, limited.length);

      final items = <ChoiceItem>[];
      for (var i = 0; i < limited.length; i++) {
        items.add(ChoiceItem(
          text: limited[i].value,
          isCorrect: i == correctIdx,
          rationale: rationalsByIndex[i],
        ));
      }
      return NormalizedChoices(items);
    }

    // choices が不正な場合のフォールバック
    final fallback = [
      ChoiceItem(text: '選択肢 1', isCorrect: true),
      ChoiceItem(text: '選択肢 2', isCorrect: false),
      ChoiceItem(text: '選択肢 3', isCorrect: false),
      ChoiceItem(text: '選択肢 4', isCorrect: false),
    ];
    return NormalizedChoices(fallback);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int? _letterToIndex(String s) {
    if (s.isEmpty) return null;
    final up = s.trim().toUpperCase();
    final code = up.codeUnitAt(0) - 'A'.codeUnitAt(0);
    if (code < 0 || code > 25) return null;
    return code;
  }

  /// rationales をインデックス基準の Map<int,String> に変換（choices が配列のとき）
  static Map<int, String> _extractRationalesByIndex(dynamic raw, int length) {
    if (raw == null) return {};
    // 配列とみなせる場合
    if (raw is List) {
      final out = <int, String>{};
      for (var i = 0; i < raw.length && i < length; i++) {
        final s = raw[i]?.toString() ?? '';
        if (s.trim().isNotEmpty) out[i] = s;
      }
      return out;
    }
    // 文字キー（A〜D）のマップ
    if (raw is Map) {
      final byLetter = _extractRationalesByIndexFromLetterMap(raw, length);
      return byLetter;
    }
    return {};
  }

  /// rationales が A〜D キーのマップだった場合に、インデックス基準に変換
  static Map<int, String> _extractRationalesByIndexFromLetterMap(dynamic raw, int length) {
    if (raw is! Map) return {};
    final out = <int, String>{};
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    for (var i = 0; i < length && i < letters.length; i++) {
      final s = raw[letters[i]]?.toString() ?? '';
      if (s.trim().isNotEmpty) out[i] = s;
    }
    return out;
  }
}