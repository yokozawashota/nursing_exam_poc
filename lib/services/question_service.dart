// lib/services/question_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../data/categories.dart';            // domains/majors/mids/topics（一般・状況設定）
import '../data/hisshu_categories.dart';     // 必修：大>中>小
import '../services/topic_picker.dart';
import '../services/settings_service.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static final Random _rng = Random(); // 完全一様ランダム（履歴なし）

  /// 看護師国試の問題を生成
  ///
  /// [difficulty] : '必修問題' / '一般問題' / '状況設定問題'
  /// [domain]     : 分野（例「人体の構造と機能」, '必修' は kHisshuCategory を使用）
  /// [major]      : 大項目（必須）
  /// [mid]        : 中項目（任意。null なら内部で自動選定）
  /// [scenarioAspect] : 状況設定の観点（'A'～'E'。任意）
  static Future<Map<String, dynamic>> fetchQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,
  }) async {
    final apiKey = await SettingsService.getApiKey();
    final model  = await SettingsService.getModel();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('OpenAI APIキーが未設定です。設定画面から入力してください。');
    }

    final bool isHisshu = domain == kHisshuCategory;

    // ===== 実際に使う mid / topic を確定 =====
    String? resolvedMid;
    String? topic;

    if (isHisshu) {
      // 必修：UIは大項目のみ → 中/小は内部
      final mids = hisshuMidsOf(major);
      if (mids.isNotEmpty) {
        resolvedMid = await TopicPicker.pickHisshuMidForMajor(major, mids);
        final topics = hisshuTopicsOf(major, resolvedMid);
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: kHisshuCategory,
            major : major,
            mid   : resolvedMid,
            topics: topics,
          );
        }
      }
    } else {
      // 一般/状況設定：中項目は任意。未指定なら内部で選定。
      if (mid != null && mid.isNotEmpty) {
        resolvedMid = mid;
      } else {
        final mids = midsOf(domain, major);
        if (mids.isNotEmpty) {
          resolvedMid = await TopicPicker.pickMidForMajor(
            domain: domain,
            major : major,
            mids  : mids,
          );
        }
      }
      if (resolvedMid != null && resolvedMid.isNotEmpty) {
        final topics = topicsOf(domain, major, resolvedMid);
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: domain,
            major : major,
            mid   : resolvedMid,
            topics: topics,
          );
        }
      }
    }

    // ===== プロンプト =====
    final system = _buildSystemPrompt();
    final user   = _buildUserPrompt(
      difficulty: difficulty,
      domain    : domain,
      major     : major,
      mid       : resolvedMid,
      topic     : topic,
      scenarioAspect: scenarioAspect,
    );

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.6,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user',   'content': user},
        ],
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('OpenAIリクエスト失敗 (${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
    jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = (data['choices'] as List).first['message']['content']?.toString() ?? '';

    Map<String, dynamic> jsonOut = {};
    try {
      jsonOut = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (m != null) {
        jsonOut = jsonDecode(m.group(0)!) as Map<String, dynamic>;
      } else {
        throw StateError('JSON抽出に失敗: $content');
      }
    }

    // ===== 正規化 =====
    final String question = _pickString(jsonOut, ['question','questionText','text']).trim();
    if (question.isEmpty) {
      throw StateError('生成結果が不完全です（question が空）');
    }

    // choices（配列/マップ いずれにも対応）＋ correct（index/letter いずれにも対応）
    final _NormalizedChoices normalized = _normalizeChoicesAndAnswer(jsonOut);

    // --- 完全一様ランダム：ここでシャッフルして A〜D を振り直す（履歴不使用） ---
    final shuffled = List<_ChoiceItem>.from(normalized.items);
    shuffled.shuffle(_rng); // Fisher–Yates（均等）

    // A-D ラベルを再付与し、正答ラベルとラショナーレを再マッピング
    const letters = ['A','B','C','D','E','F','G','H'];
    final Map<String, String> outChoices = {};
    final Map<String, String> outRationales = {};
    String? correctLetter;
    int? correctIndex;

    for (var i = 0; i < shuffled.length && i < letters.length; i++) {
      final label = letters[i];
      final item  = shuffled[i];
      outChoices[label] = item.text;
      if (item.rationale != null && item.rationale!.trim().isNotEmpty) {
        outRationales[label] = item.rationale!;
      }
      if (item.isCorrect) {
        correctLetter = label;
        correctIndex  = i;
      }
    }

    // 念のため 2〜4択に制限（UIは存在キーのみ描画）
    final limitedChoices = Map<String,String>.fromEntries(outChoices.entries.take(4));
    final limitedRationales = Map<String,String>.fromEntries(
      outRationales.entries.where((e) => limitedChoices.containsKey(e.key)),
    );

    // 正答ラベルとインデックスの整合性を再確認（万一なければ先頭を正答に）
    if (correctLetter == null || !limitedChoices.containsKey(correctLetter)) {
      // 先頭を正答として採用（均等性は shuffle 済みなので位置はランダム）
      correctLetter = limitedChoices.keys.isNotEmpty ? limitedChoices.keys.first : 'A';
      correctIndex  = 0;
    } else {
      // 正答の index を limitedChoices 上で計算し直す
      final keys = limitedChoices.keys.toList();
      correctIndex = keys.indexOf(correctLetter);
    }

    final String explanation =
    _pickString(jsonOut, ['explanation','reason','解説']).trim();

    return {
      'question'     : question,
      'choices'      : limitedChoices,     // Map<A-D, text>
      'correct'      : correctLetter,      // 'A' | 'B' | 'C' | 'D'
      'correctIndex' : correctIndex,       // 0..3（UI側の互換性のため併記）
      'explanation'  : explanation,
      if (limitedRationales.isNotEmpty) 'rationales': limitedRationales,
      // 参考情報（履歴詳細で使える）
      'meta': {
        'difficulty'    : difficulty,
        'domain'        : domain,
        'major'         : major,
        'mid'           : resolvedMid,
        'topic'         : topic,
        if (scenarioAspect != null) 'scenarioAspect': scenarioAspect,
      }
    };
  }

  // ===== Prompts =====
  static String _buildSystemPrompt() {
    return 'あなたは日本の看護師国家試験の出題委員です。'
        '厚労省の出題基準に準拠し、日本語として自然で学術的に正確な択一式（4択）問題を作成します。'
        '出力は必ず JSON オブジェクトのみ。'
        '形式の例: {"question": string, "choices": [string,string,string,string], "correctIndex": number, "explanation": string, "rationales": {"A": "...", "B": "...", "C": "...", "D": "..."}}';
  }

  static String _buildUserPrompt({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? topic,
    String? scenarioAspect,
  }) {
    final b = StringBuffer();
    b.writeln('出題形式: $difficulty');      // 必修問題 / 一般問題 / 状況設定問題
    b.writeln('分野: $domain');              // 例：人体の構造と機能
    b.writeln('大項目: $major');            // 例：1. 細胞と組織
    if (mid != null && mid.isNotEmpty) {
      b.writeln('中項目: $mid');            // 例：A. 細胞の構造
    } else {
      b.writeln('中項目: 大項目内から自動選定');
    }
    if (topic != null && topic.isNotEmpty) {
      b.writeln('小項目(内部選定): $topic');
    }
    if (difficulty.contains('状況設定') && scenarioAspect != null && scenarioAspect.isNotEmpty) {
      b.writeln('状況設定の観点: $scenarioAspect'); // 'A'〜'E'
    }
    b.writeln('制約:');
    b.writeln('- choices は 4 つ（配列または A〜D のマップのどちらでも良い）');
    b.writeln('- 正答を correctIndex (0〜3) か correct (A〜D) で必ず返す');
    if (difficulty.contains('状況設定')) {
      b.writeln('- 問題文は150〜250字程度で具体的な状況を提示');
    } else if (difficulty.contains('必修')) {
      b.writeln('- 基礎的知識の確認に焦点');
    }
    b.writeln('- 各選択肢にはもっともらしい理由があるように（可能なら rationales も返す）');
    b.writeln('- 最新の標準的看護実践に合致');
    return b.toString();
  }

  // ===== Helpers =====

  static String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  // JSON から choices と正答を正規化（内部形式：リスト＋ isCorrect＋ rationale）
  static _NormalizedChoices _normalizeChoicesAndAnswer(Map<String, dynamic> json) {
    final dynamic rawChoices = json['choices'];
    final dynamic rawRationales = json['rationales'] ?? json['reasons'] ?? json['rationale'];

    // 正答マーカー抽出
    final int? idxFromNum = _asInt(json['correctIndex'] ?? json['answer_index'] ?? json['answerIndex']);
    final String letterFromJson = (json['correct'] ?? json['correctLetter'] ?? json['answer_key'] ?? json['answer'] ?? '').toString().trim();

    if (rawChoices is List) {
      // 例：["a","b","c","d"]
      final list = rawChoices.map((e) => (e ?? '').toString()).where((s) => s.isNotEmpty).toList();
      // 2〜4 要素に丸める（多すぎる分は切り捨て）
      final limited = list.length > 4 ? list.take(4).toList() : list;

      // インデックスの確定（未提示なら 0 として受け取り → 後段のシャッフルで均等化）
      int correctIdx = 0;
      if (idxFromNum != null && idxFromNum >= 0 && idxFromNum < limited.length) {
        correctIdx = idxFromNum;
      } else {
        final idxFromLetter = _letterToIndex(letterFromJson);
        if (idxFromLetter != null && idxFromLetter >= 0 && idxFromLetter < limited.length) {
          correctIdx = idxFromLetter;
        }
      }

      final rationalsByIndex = _extractRationalesByIndex(rawRationales, limited.length);

      final items = <_ChoiceItem>[];
      for (var i = 0; i < limited.length; i++) {
        items.add(_ChoiceItem(
          text: limited[i],
          isCorrect: i == correctIdx,
          rationale: rationalsByIndex[i],
        ));
      }
      return _NormalizedChoices(items);
    }

    if (rawChoices is Map) {
      // 例：{"A":"a","B":"b","C":"c","D":"d"}
      final order = ['A','B','C','D','E','F'];
      final entries = <MapEntry<String,String>>[];
      for (final k in order) {
        final v = rawChoices[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.trim().isEmpty) continue;
        entries.add(MapEntry(k, s));
      }
      // 2〜4件に制限
      final limited = entries.take(4).toList();

      // 正答：数値 or 文字（未提示なら 0 として受け取り → 後段で均等化）
      int correctIdx = 0;
      if (idxFromNum != null && idxFromNum >= 0 && idxFromNum < limited.length) {
        correctIdx = idxFromNum;
      } else {
        final idxFromLetter = _letterToIndex(letterFromJson);
        if (idxFromLetter != null && idxFromLetter >= 0 && idxFromLetter < limited.length) {
          correctIdx = idxFromLetter;
        }
      }

      // ラショナーレ取得（A-D マップ基準で受け取り → インデックスへ）
      final rationalsByIndex = _extractRationalesByIndexFromLetterMap(rawRationales, limited.length);

      final items = <_ChoiceItem>[];
      for (var i = 0; i < limited.length; i++) {
        items.add(_ChoiceItem(
          text: limited[i].value,
          isCorrect: i == correctIdx,
          rationale: rationalsByIndex[i],
        ));
      }
      return _NormalizedChoices(items);
    }

    // choices が不正な場合のフォールバック
    final fallback = [
      _ChoiceItem(text: '選択肢 1', isCorrect: true),
      _ChoiceItem(text: '選択肢 2', isCorrect: false),
      _ChoiceItem(text: '選択肢 3', isCorrect: false),
      _ChoiceItem(text: '選択肢 4', isCorrect: false),
    ];
    return _NormalizedChoices(fallback);
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
  static Map<int,String> _extractRationalesByIndex(dynamic raw, int length) {
    if (raw == null) return {};
    // 配列とみなせる場合
    if (raw is List) {
      final out = <int,String>{};
      for (var i = 0; i < raw.length && i < length; i++) {
        final s = raw[i]?.toString() ?? '';
        if (s.trim().isNotEmpty) out[i] = s;
      }
      return out;
    }
    // 文字キー（A〜D）のマップ
    if (raw is Map) {
      return _extractRationalesByIndexFromLetterMap(raw, length);
    }
    return {};
  }

  /// rationales が A〜D キーのマップだった場合に、インデックス基準に変換
  static Map<int,String> _extractRationalesByIndexFromLetterMap(dynamic raw, int length) {
    if (raw is! Map) return {};
    final out = <int,String>{};
    const letters = ['A','B','C','D','E','F'];
    for (var i = 0; i < length && i < letters.length; i++) {
      final s = raw[letters[i]]?.toString() ?? '';
      if (s.trim().isNotEmpty) out[i] = s;
    }
    return out;
  }
}

// 内部表現：選択肢＋正誤＋（あれば）ラショナーレ
class _ChoiceItem {
  final String text;
  final bool isCorrect;
  final String? rationale;
  _ChoiceItem({required this.text, required this.isCorrect, this.rationale});
}

class _NormalizedChoices {
  final List<_ChoiceItem> items;
  _NormalizedChoices(this.items);
}