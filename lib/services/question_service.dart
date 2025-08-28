import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/categories.dart';           // 一般領域（大>中>小）
import '../data/hisshu_categories.dart';    // 必修（大>中>小：原典表記）
import '../services/topic_picker.dart';
import '../services/balanced_index_picker.dart';
import '../services/settings_service.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  /// 看護師国試の問題を生成。
  /// 一般：category=大項目, subcategory=中項目
  /// 必修：category='必修::大項目', subcategory=null（内部で中/小を選定）
  static Future<Map<String, dynamic>> fetchQuestion({
    required String category,
    required String difficulty,
    String? subcategory,
  }) async {
    final apiKey = await SettingsService.getApiKey();
    final model  = await SettingsService.getModel();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('OpenAI APIキーが未設定です。設定画面から入力してください。');
    }

    final bool isHisshu = category.startsWith(kHisshuCategory);
    String? hisshuMajor;
    if (isHisshu) {
      final idx = category.indexOf('::');
      if (idx >= 0 && idx + 2 < category.length) {
        hisshuMajor = category.substring(idx + 2);
      }
    }

    // ===== 内部選定（偏り抑制） =====
    String? mid;   // 実際に使う中項目
    String? topic; // 小項目
    if (isHisshu) {
      final major = hisshuMajor ?? hisshuMajors.first;
      final mids = hisshuMidsOf(major);
      if (mids.isNotEmpty) {
        mid = await TopicPicker.pickHisshuMidForMajor(major, mids);
        final topics = hisshuTopicsOf(major, mid);
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pick(kHisshuCategory, mid, topics);
        }
      }
    } else if (subcategory != null && subcategory.isNotEmpty) {
      mid = subcategory;
      final topics = topicsOf(category, mid);
      if (topics.isNotEmpty) {
        topic = await TopicPicker.pick(category, mid, topics);
      }
    }

    // ===== プロンプト =====
    final system = _buildSystemPrompt();
    final user   = _buildUserPrompt(
      category   : isHisshu ? kHisshuCategory : category,
      difficulty : difficulty,
      hisshuMajor: hisshuMajor,     // 必修の大項目
      subcategory: mid,             // 自動選定（一般はUI指定）
      topic      : topic,           // 自動選定（小項目）
    );

    final body = jsonEncode({
      'model': model,
      'temperature': 0.6,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user',   'content': user},
      ],
    });

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('OpenAIリクエスト失敗 (${res.statusCode}): ${res.body}');
    }

    // UTF-8 デコードで文字化け防止
    final Map<String, dynamic> data =
    jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('OpenAI応答が不正です: choices が空');
    }
    final content = choices.first['message']?['content']?.toString() ?? '';

    // JSON抽出
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

    // ---- 正規化・安全化 ----
    // 問題文
    final String question =
    _pickString(jsonOut, ['question','questionText','text']).trim();

    // 選択肢 → 4択に正規化（多すぎるときは先頭4つ／足りないときはそのまま）
    List<String> opts = _asChoices(jsonOut['choices']);
    if (opts.length > 4) {
      opts = List<String>.from(opts.take(4));
    }

    // 正解インデックス
    final int? idxFromNum =
    _asInt(jsonOut['correctIndex'] ?? jsonOut['answer_index'] ?? jsonOut['answerIndex']);
    final String letterRaw =
    _pickString(jsonOut, ['correct','correctLetter','answer_key']).trim();
    final int? idxFromLetter = _letterToIndex(letterRaw);

    int? resolvedCorrectIndex;
    if (idxFromNum != null && idxFromNum >= 0 && idxFromNum < opts.length) {
      resolvedCorrectIndex = idxFromNum;
    } else if (idxFromLetter != null && idxFromLetter >= 0 && idxFromLetter < opts.length) {
      resolvedCorrectIndex = idxFromLetter;
    } else {
      // ★ フォールバック：均等ローテーションでバランス確保（← A固定の原因を解消）
      resolvedCorrectIndex = await BalancedIndexPicker.next(length: opts.length.clamp(1, 10));
    }

    // 解説
    final String explanation =
    _pickString(jsonOut, ['explanation','reason','解説']).trim();

    if (question.isEmpty || opts.isEmpty) {
      throw StateError('生成結果が不完全です（question/choices が空）');
    }

    return {
      'question'     : question,
      'choices'      : opts,
      'correctIndex' : resolvedCorrectIndex,
      'explanation'  : explanation,
    };
  }

  // ===== Prompts =====
  static String _buildSystemPrompt() {
    return 'あなたは日本の看護師国家試験の出題委員です。'
        '厚生労働省の出題基準に準拠し、日本語として自然で学術的に正確な択一式（4択）問題を作成します。'
        '出力は必ず JSON オブジェクトのみ。'
        '形式: {"question": string, "choices": [string,string,string,string], "correctIndex": number, "explanation": string}';
  }

  static String _buildUserPrompt({
    required String category,
    required String difficulty,
    String? hisshuMajor,
    String? subcategory,
    String? topic,
  }) {
    final b = StringBuffer();
    b.writeln('出題形式: $difficulty');            // 必修問題 / 一般問題 / 状況設定問題
    b.writeln('分野(大項目): $category');           // 必修のときは「必修」
    if (hisshuMajor != null && hisshuMajor.isNotEmpty) {
      b.writeln('必修の大項目: $hisshuMajor');       // 例：健康の定義と理解
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      b.writeln('項目(中項目): $subcategory');       // 自動選定
    }
    if (topic != null && topic.isNotEmpty) {
      b.writeln('小項目(内部選定): $topic');         // 自動選定
    }
    b.writeln('制約:');
    b.writeln('- choices は 4 つ、いずれも日本語の自然な文（4つ未満は不可）');
    b.writeln('- correctIndex は 0〜3 の整数で必ず返す（letter ではなく index を推奨）');
    if (difficulty.contains('状況設定')) {
      b.writeln('- 問題文は150〜250字程度で、患者背景や現場状況を具体的に設定');
    } else if (difficulty.contains('必修')) {
      b.writeln('- 基礎的知識の確認に焦点');
    }
    b.writeln('- 誤答にももっともらしい理由があるように');
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

  static List<String> _asChoices(dynamic v) {
    if (v == null) return const <String>[];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (v is Map) {
      final keys = ['A','B','C','D'];
      return keys.map((k) => v[k]?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const <String>[];
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
}