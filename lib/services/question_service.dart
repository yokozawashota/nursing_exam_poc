// lib/services/question_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/hisshu_categories.dart';
import '../services/topic_picker.dart';
import '../services/settings_service.dart';
import 'prompt_builder.dart';
import 'response_parser.dart';
import 'category_repository.dart';
import '../models/category_models.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  static Future<Map<String, dynamic>> fetchQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,
  }) async {
    final apiKey = await SettingsService.getApiKey();
    final model = await SettingsService.getModel() ?? 'gpt-4o-mini';
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('OpenAI APIキーが未設定です。設定画面から入力してください。');
    }

    // ===== ユーザー設定の読み取り =====
    final choiceMode = await SettingsService.getChoiceMode() ?? 'auto';
    final probFiveChoice = (await SettingsService.getFiveChoiceProbability()) ?? 0;
    final probMultiple = (await SettingsService.getMultipleKindProbability()) ?? 0;
    final probIncorrect = (await SettingsService.getIncorrectKindProbability()) ?? 0;

    debugPrint(
      '[log] [SETTINGS] ChoiceMode=$choiceMode | 5択確率=${probFiveChoice}% | '
          '複数選択確率=${probMultiple}% | 誤答確率=${probIncorrect}%',
    );

    // ===== 出題形式を決定 =====
    final rand = Random(DateTime.now().microsecondsSinceEpoch);
    int desiredChoiceCount;
    switch (choiceMode) {
      case 'force4':
        desiredChoiceCount = 4;
        break;
      case 'force5':
        desiredChoiceCount = 5;
        break;
      default:
        desiredChoiceCount = rand.nextInt(100) < probFiveChoice ? 5 : 4;
        break;
    }

    final bool wantMultiple = rand.nextInt(100) < probMultiple;
    final bool wantIncorrect = rand.nextInt(100) < probIncorrect;

    String desiredKind;
    int requiredCorrectCount;

    if (wantIncorrect && wantMultiple) {
      desiredKind = 'select_incorrect';
      requiredCorrectCount = 2;
    } else if (wantIncorrect) {
      desiredKind = 'select_incorrect';
      requiredCorrectCount = 1;
    } else if (wantMultiple) {
      desiredKind = 'multiple';
      requiredCorrectCount = 2;
    } else {
      desiredKind = 'single';
      requiredCorrectCount = 1;
    }

    debugPrint(
      '[log] [QS] desiredChoiceCount=$desiredChoiceCount | '
          'requiredCorrectCount=$requiredCorrectCount | desiredKind=$desiredKind',
    );

    // ===== mid / topic 決定 =====
    final bool isHisshu = domain == kHisshuCategory;
    String? resolvedMid;
    String? topic;

    if (isHisshu) {
      final DomainCategory tree = CategoryRepository.buildHisshuTree();
      final MajorCategory majorNode = tree.majors.firstWhere(
            (m) => m.id == major,
        orElse: () => tree.majors.isNotEmpty
            ? tree.majors.first
            : MajorCategory(id: major, label: major, mids: const []),
      );
      final mids = majorNode.mids.map((m) => m.id).toList();
      if (mids.isNotEmpty) {
        resolvedMid = await TopicPicker.pickHisshuMidForMajor(majorNode.id, mids);
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[]).map((t) => t.label).toList();
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: kHisshuCategory,
            major: majorNode.id,
            mid: resolvedMid,
            topics: topics,
          );
        }
      }
    } else {
      final DomainCategory tree = CategoryRepository.buildGeneralDomainTree(domain);
      final MajorCategory majorNode = tree.majors.firstWhere(
            (m) => m.id == major,
        orElse: () => tree.majors.isNotEmpty
            ? tree.majors.first
            : MajorCategory(id: major, label: major, mids: const []),
      );

      if (mid != null && mid.isNotEmpty) {
        resolvedMid = mid;
      } else {
        final mids = majorNode.mids.map((m) => m.id).toList();
        if (mids.isNotEmpty) {
          resolvedMid = await TopicPicker.pickMidForMajor(
            domain: domain,
            major: majorNode.id,
            mids: mids,
          );
        }
      }

      if (resolvedMid != null && resolvedMid!.isNotEmpty) {
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[]).map((t) => t.label).toList();
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: domain,
            major: majorNode.id,
            mid: resolvedMid,
            topics: topics,
          );
        }
      }
    }

    // ===== プロンプト生成 =====
    final system = PromptBuilder.buildSystemPrompt(
      desiredKind: desiredKind,
      desiredChoiceCount: desiredChoiceCount,
      requiredCorrectCount: requiredCorrectCount,
    );

    final user = PromptBuilder.buildUserPrompt(
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: resolvedMid,
      topic: topic,
      scenarioAspect: scenarioAspect,
      desiredKind: desiredKind,
      desiredChoiceCount: desiredChoiceCount,
      requiredCorrectCount: requiredCorrectCount,
    );

    // ===== LLM 呼び出し =====
    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.4,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('OpenAIリクエスト失敗 (${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> root =
    jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final String content =
        (root['choices'] as List).first['message']['content']?.toString() ?? '';

    debugPrint('[log] [QS] raw content (head) = ${_firstLines(content)}');

    final out = ResponseParser.parseContentToQuestion(
      content,
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: resolvedMid,
      topic: topic,
    );

    final Map<String, String>? choices =
    (out['choices'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()));

    final List<String> correct =
        ((out['correctAnswers'] as List?)?.map((e) => e.toString()).toList()) ?? [];

    if (choices != null) {
      final present = choices.keys.toSet();
      final filtered = correct.where(present.contains).toList();

      out['correctAnswers'] =
      filtered.isNotEmpty ? filtered : (choices.isNotEmpty ? [choices.keys.first] : []);

      final isMulti = desiredKind == 'multiple' || desiredKind == 'select_incorrect';
      final q = (out['question'] as String? ?? '').trim();
      out['question'] = _ensureCountInstruction(
        q,
        isMulti: isMulti,
        requiredCorrectCount: requiredCorrectCount,
      );
    }

    debugPrint(
      '[log] [QS] parsed => kind=${out['questionKind']}, choices=${(out['choices'] as Map?)?.keys.join(',') ?? ''} (len=${(out['choices'] as Map?)?.length ?? 0}), correct=${(out['correctAnswers'] as List?)?.join(',') ?? ''}',
    );

    return out;
  }

  static MidCategory? _findMidNode(MajorCategory? majorNode, String? midId) {
    if (majorNode == null || majorNode.mids.isEmpty) return null;
    if (midId != null && midId.isNotEmpty) {
      try {
        return majorNode.mids.firstWhere((x) => x.id == midId);
      } catch (_) {}
    }
    return majorNode.mids.first;
  }

  static String _ensureCountInstruction(
      String q, {
        required bool isMulti,
        required int requiredCorrectCount,
      }) {
    if (!isMulti || requiredCorrectCount <= 1) return q;

    final already = RegExp(r'[0-9一二三四五六七八九十]+\s*つ\s*選んでください').hasMatch(q);
    if (already) return q;

    return '$q ${requiredCorrectCount}つ選んでください';
  }

  static String _firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    return (t.length <= maxChars) ? t : t.substring(0, maxChars) + '...';
  }
}