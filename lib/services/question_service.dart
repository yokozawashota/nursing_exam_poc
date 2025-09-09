// lib/services/question_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../data/categories.dart';           // domains/majors/mids/topics（一般・状況設定）
import '../data/hisshu_categories.dart';    // 必修：大>中>小
import '../services/topic_picker.dart';
import '../services/settings_service.dart';

// ★ 追加：選択肢正規化ユーティリティ
import 'choice_normalizer.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  static final Random _rng = Random();

  /// 看護師国試の問題を生成
  ///
  /// [difficulty] : '必修問題' / '一般問題' / '状況設定問題'
  /// [domain]     : 分野（例「人体の構造と機能」, '必修' は kHisshuCategory を使用）
  /// [major]      : 大項目（必須）
  /// [mid]        : 中項目（任意。null なら内部で自動選定）
  static Future<Map<String, dynamic>> fetchQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    // ※ もし呼び出し側で `scenarioAspect:` を渡している構成なら、
    //    ここに `String? scenarioAspect,` を残してください（未使用でもOK）。
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
      if (resolvedMid != null && resolvedMid!.isNotEmpty) {
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
      // ここで scenarioAspect を使う設計なら、適宜 user に書き込みを追加
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
    final NormalizedChoices normalized = ChoiceNormalizer.normalize(jsonOut);

    // --- 完全一様ランダムに正答位置を決めるため、ここでシャッフルして A〜D を振り直す ---
    final shuffled = List<ChoiceItem>.from(normalized.items);
    shuffled.shuffle(_rng); // Fisher–Yates（List.shuffle は均等）

    // A-D ラベルを再付与し、正答ラベルとラショナーレを再マッピング
    const letters = ['A','B','C','D','E','F','G','H'];
    final Map<String, String> outChoices = {};
    final Map<String, String> outRationales = {};
    String? correctLetter;

    for (var i = 0; i < shuffled.length && i < letters.length; i++) {
      final label = letters[i];
      final item  = shuffled[i];
      outChoices[label] = item.text;
      if (item.rationale != null && item.rationale!.trim().isNotEmpty) {
        outRationales[label] = item.rationale!;
      }
      if (item.isCorrect) correctLetter = label;
    }

    // 念のため 2〜4択に制限（UIは存在キーのみ描画）
    final limitedChoices = Map<String,String>.fromEntries(
      outChoices.entries.take(4),
    );
    final limitedRationales = Map<String,String>.fromEntries(
      outRationales.entries.where((e) => limitedChoices.containsKey(e.key)),
    );

    // 正答ラベルが消えていないか最終確認（万一なければ先頭を正答に）
    correctLetter ??= limitedChoices.keys.isNotEmpty ? limitedChoices.keys.first : 'A';

    final String explanation =
    _pickString(jsonOut, ['explanation','reason','解説']).trim();

    return {
      'question'    : question,
      'choices'     : limitedChoices,     // Map<A-D, text>
      'correct'     : correctLetter,      // 'A' | 'B' | 'C' | 'D'
      'explanation' : explanation,
      if (limitedRationales.isNotEmpty) 'rationales': limitedRationales,
      // 参考情報（履歴詳細で使える）
      'meta': {
        'difficulty': difficulty,
        'domain'    : domain,
        'major'     : major,
        'mid'       : resolvedMid,
        'topic'     : topic,
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
}