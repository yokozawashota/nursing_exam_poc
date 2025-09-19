// lib/services/question_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/hisshu_categories.dart';  // kHisshuCategory（定数のみ利用）
import '../services/topic_picker.dart';
import '../services/settings_service.dart';

import 'prompt_builder.dart';        // system/user プロンプト組み立て
import 'response_parser.dart';       // API応答 → 画面向け Map に正規化
import 'category_repository.dart';   // 型付きツリーから mid/topic を選定
import '../models/category_models.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  /// 看護師国試の問題を生成（戻り値は画面がそのまま使える Map 形式）
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

    // ===== 必修／一般／状況設定の分岐 =====
    final bool isHisshu = domain == kHisshuCategory;

    // 今回使う mid / topic を確定（未指定は内部で安全に選定）
    String? resolvedMid;
    String? topic;

    if (isHisshu) {
      // ---------- 必修：型付きツリーから mid / topic を選定 ----------
      final DomainCategory tree = CategoryRepository.buildHisshuTree();

      // majorノード（なければ先頭 or 空ノード）
      final MajorCategory majorNode = tree.majors.firstWhere(
            (m) => m.id == major,
        orElse: () => tree.majors.isNotEmpty
            ? tree.majors.first
            : MajorCategory(id: major, label: major, mids: const []),
      );

      // mid 候補一覧
      final mids = majorNode.mids.map((m) => m.id).toList(growable: false);
      if (mids.isNotEmpty) {
        resolvedMid = await TopicPicker.pickHisshuMidForMajor(majorNode.id, mids);

        // topic 候補
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[])
            .map((t) => t.label)
            .toList(growable: false);

        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: kHisshuCategory,
            major : majorNode.id,
            mid   : resolvedMid,
            topics: topics,
          );
        }
      }
    } else {
      // ---------- 一般/状況設定：型付きツリーから mid / topic を選定 ----------
      final DomainCategory tree = CategoryRepository.buildGeneralDomainTree(domain);

      // majorノード（なければ先頭 or 空ノード）
      final MajorCategory majorNode = tree.majors.firstWhere(
            (m) => m.id == major,
        orElse: () => tree.majors.isNotEmpty
            ? tree.majors.first
            : MajorCategory(id: major, label: major, mids: const []),
      );

      // mid 指定があれば優先、なければ TopicPicker で選定
      if (mid != null && mid.isNotEmpty) {
        resolvedMid = mid;
      } else {
        final mids = majorNode.mids.map((m) => m.id).toList(growable: false);
        if (mids.isNotEmpty) {
          resolvedMid = await TopicPicker.pickMidForMajor(
            domain: domain,
            major : majorNode.id,
            mids  : mids,
          );
        }
      }

      if (resolvedMid != null && resolvedMid!.isNotEmpty) {
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[])
            .map((t) => t.label)
            .toList(growable: false);

        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: domain,
            major : majorNode.id,
            mid   : resolvedMid,
            topics: topics,
          );
        }
      }
    }

    // ===== プロンプト =====
    final system = PromptBuilder.buildSystemPrompt();
    final user   = PromptBuilder.buildUserPrompt(
      difficulty: difficulty,
      domain    : domain,
      major     : major,
      mid       : resolvedMid,
      topic     : topic,
      scenarioAspect: scenarioAspect,
    );

    // ===== API 呼び出し =====
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

    // ===== レスポンス標準化 =====
    final Map<String, dynamic> root =
    jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final String content =
        (root['choices'] as List).first['message']['content']?.toString() ?? '';

    // content → 画面が使える Map に整形（シャッフル・4択制限・正答追随を含む）
    final out = ResponseParser.parseContentToQuestion(
      content,
      difficulty: difficulty,
      domain    : domain,
      major     : major,
      mid       : resolvedMid,
      topic     : topic,
    );

    return out;
  }

  /// majorNode と midId から MidCategory を安全に取得（なければ先頭、なければ null）
  static MidCategory? _findMidNode(MajorCategory? majorNode, String? midId) {
    if (majorNode == null || majorNode.mids.isEmpty) return null;
    if (midId != null && midId.isNotEmpty) {
      try {
        return majorNode.mids.firstWhere((x) => x.id == midId);
      } catch (_) {
        // 見つからなければ先頭へフォールバック
      }
    }
    return majorNode.mids.first;
  }
}