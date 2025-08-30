// lib/services/question_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/categories.dart';           // domains/majors/mids/topics
import '../data/hisshu_categories.dart';    // 必修大>中>小
import '../services/topic_picker.dart';
import '../services/balanced_index_picker.dart';
import '../services/settings_service.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  /// 看護師国試の問題を生成
  ///
  /// 一般／状況設定：
  ///   - domain: 分野（例「人体の構造と機能」）
  ///   - major : 大項目（必須）
  ///   - mid   : 中項目（任意。nullなら大項目配下の全中項目から内部で選定）
  ///
  /// 必修：
  ///   - domain: '必修'
  ///   - major : 必修の大項目（UIで選択）
  ///   - mid   : 指定不要（内部で自動）
  static Future<Map<String, dynamic>> fetchQuestion({
    required String difficulty,  // '必修問題' / '一般問題' / '状況設定問題'
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,      // 'A'〜'E'（状況設定の観点、任意）
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
      // 必修：UIは大項目のみ → 中/小は内部選定
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
      // 一般/状況設定：中項目は任意
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
      difficulty    : difficulty,
      domain        : domain,
      major         : major,
      mid           : resolvedMid,
      topic         : topic,
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

    final String question =
    _pickString(jsonOut, ['question','questionText','text']).trim();

    // choices → 4択に正規化（List or Map を吸収）
    List<String> opts = _asChoices(jsonOut['choices']);
    if (opts.length > 4) opts = List<String>.from(opts.take(4));

    // 正答インデックス：なければバランサで決定
    final int? idxNum =
    _asInt(jsonOut['correctIndex'] ?? jsonOut['answer_index'] ?? jsonOut['answerIndex']);
    int resolvedCorrectIndex =
    (idxNum != null && idxNum >= 0 && idxNum < opts.length)
        ? idxNum
        : await BalancedIndexPicker.next(length: opts.length.clamp(1, 10));

    final String explanation =
    _pickString(jsonOut, ['explanation','reason','解説']).trim();

    if (question.isEmpty || opts.isEmpty) {
      throw StateError('生成結果が不完全です（question/choices が空）');
    }

    return {
      'question'     : question,
      'choices'      : opts,                 // List<String>
      'correctIndex' : resolvedCorrectIndex, // int
      'explanation'  : explanation,
      'meta': {
        'domain'    : domain,
        'major'     : major,
        'mid'       : resolvedMid,
        'topic'     : topic,
        'difficulty': difficulty,
        if (scenarioAspect != null) 'scenarioAspect': scenarioAspect,
      }
    };
  }

  // ===== Prompts =====
  static String _buildSystemPrompt() {
    return 'あなたは日本の看護師国家試験の出題委員です。'
        '厚労省の出題基準に準拠し、日本語として自然で学術的に正確な択一式（4択）問題を作成します。'
        '出力は必ず JSON オブジェクトのみ。'
        '形式: {"question": string, "choices": [string,string,string,string], "correctIndex": number, "explanation": string}';
  }

  static String _buildUserPrompt({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? topic,
    String? scenarioAspect, // 'A'〜'E'
  }) {
    final b = StringBuffer();
    b.writeln('出題形式: $difficulty');      // 必修問題 / 一般問題 / 状況設定問題
    b.writeln('分野: $domain');
    b.writeln('大項目: $major');
    if (mid != null && mid.isNotEmpty) {
      b.writeln('中項目: $mid');
    } else {
      b.writeln('中項目: 大項目内から自動選定');
    }
    if (topic != null && topic.isNotEmpty) {
      b.writeln('小項目(内部選定): $topic');
    }
    if (difficulty.contains('状況設定') && scenarioAspect != null) {
      b.writeln('状況設定の観点: $scenarioAspect'); // 'A'〜'E'
    }
    b.writeln('制約:');
    b.writeln('- choices は 4 つ、いずれも日本語の自然な文');
    b.writeln('- correctIndex は 0〜3 の整数で必ず返す');
    if (difficulty.contains('状況設定')) {
      b.writeln('- 問題文は150〜250字程度で具体的な状況を提示');
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