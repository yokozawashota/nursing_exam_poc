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
    final model  = await SettingsService.getModel() ?? 'gpt-4o-mini';
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('OpenAI APIキーが未設定です。設定画面から入力してください。');
    }

    // ===== Settings =====
    final choiceMode     = await SettingsService.getChoiceMode() ?? 'auto'; // 'auto'|'force4'|'force5'
    final probFiveChoice = (await SettingsService.getFiveChoiceProbability()) ?? 0;
    final probMultiple   = (await SettingsService.getMultipleKindProbability()) ?? 0;
    final probIncorrect  = (await SettingsService.getIncorrectKindProbability()) ?? 0;

    debugPrint('[log] [SETTINGS] ChoiceMode=$choiceMode | 5択確率=${probFiveChoice}% | 複数選択確率=${probMultiple}% | 誤答確率=${probIncorrect}%');

    // ===== mid/topic resolve =====
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
      final mids = majorNode.mids.map((m) => m.id).toList(growable: false);
      if (mids.isNotEmpty) {
        resolvedMid = await TopicPicker.pickHisshuMidForMajor(majorNode.id, mids);
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[]).map((t) => t.label).toList(growable: false);
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(
            domain: kHisshuCategory, major: majorNode.id, mid: resolvedMid, topics: topics,
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
        final mids = majorNode.mids.map((m) => m.id).toList(growable: false);
        if (mids.isNotEmpty) {
          resolvedMid = await TopicPicker.pickMidForMajor(domain: domain, major: majorNode.id, mids: mids);
        }
      }
      if (resolvedMid != null && resolvedMid!.isNotEmpty) {
        final MidCategory? midNode = _findMidNode(majorNode, resolvedMid);
        final topics = (midNode?.topics ?? const <Topic>[]).map((t) => t.label).toList(growable: false);
        if (topics.isNotEmpty) {
          topic = await TopicPicker.pickTopic(domain: domain, major: majorNode.id, mid: resolvedMid, topics: topics);
        }
      }
    }

    // ===== sample spec from settings =====
    final rand = Random(DateTime.now().microsecondsSinceEpoch);

    int desiredChoiceCount;
    switch (choiceMode) {
      case 'force4': desiredChoiceCount = 4; break;
      case 'force5': desiredChoiceCount = 5; break;
      default: desiredChoiceCount = rand.nextInt(100) < probFiveChoice ? 5 : 4; break;
    }

    final bool wantMultiple  = rand.nextInt(100) < probMultiple;
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

    // order fixed: choiceCount -> requiredCorrectCount -> kind
    debugPrint('[log] [QS] desiredChoiceCount=$desiredChoiceCount | requiredCorrectCount=$requiredCorrectCount | desiredKind=$desiredKind');

    // ===== prompt =====
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

    // ===== call =====
    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json','Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': model,
        'temperature': 0.3,
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

    // safety: intersect only
    final Map<String, String>? choices =
    (out['choices'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()));
    final List<String> correct =
        ((out['correctAnswers'] as List?)?.map((e) => e.toString()).toList()) ?? [];

    if (choices != null) {
      final present = choices.keys.toSet();
      final filtered = correct.where(present.contains).toList();
      out['correctAnswers'] = filtered.isNotEmpty
          ? filtered
          : (choices.isNotEmpty ? [choices.keys.first] : <String>[]);

      // ---- FIX: count-instruction unique & unified ----
      final isMulti = desiredKind == 'multiple' || desiredKind == 'select_incorrect';
      final q = (out['question'] as String? ?? '').trim();
      out['question'] = _ensureCountInstructionUnique(
        q,
        isMulti: isMulti,
        requiredCorrectCount: requiredCorrectCount,
      );
    }

    debugPrint(
      '[log] [QS] parsed => kind=${out['questionKind']}, '
          'choices=${(out['choices'] as Map?)?.keys.join(',') ?? ''} '
          '(len=${(out['choices'] as Map?)?.length ?? 0}), '
          'correct=${(out['correctAnswers'] as List?)?.join(',') ?? ''}',
    );

    return out;
  }

  static MidCategory? _findMidNode(MajorCategory? majorNode, String? midId) {
    if (majorNode == null || majorNode.mids.isEmpty) return null;
    if (midId != null && midId.isNotEmpty) {
      try { return majorNode.mids.firstWhere((x) => x.id == midId); } catch (_) {}
    }
    return majorNode.mids.first;
  }

  // ------------------------------------------------------------------
  // 文言補正（重複防止＆統一）: 「nつ選んでください」を1回だけ
  // ------------------------------------------------------------------
  static String _ensureCountInstructionUnique(
      String q, {
        required bool isMulti,
        required int requiredCorrectCount,
      }) {
    if (!isMulti || requiredCorrectCount <= 1) return q;

    // 1) 既存の多様な指示表現を除去／置換対象として検出
    //   - 2つ/二つ/２つ（半角/全角）
    //   - 選べ / 選びなさい / 選んでください
    //   - すべて選びなさい / 全て選びなさい
    //   - かっこ付き（（）/()）も許容
    final numPattern = r'(?:[0-9０-９]|一|二|三|四|五|六|七|八|九|十)+';
    final baseCountCmd = RegExp(
      // 例: 「(2つ選べ)」「２つ 選びなさい」「二つ選んでください」など
      r'[（(]?\s*' + numPattern + r'\s*つ\s*選(?:べ|びなさい|んでください)\s*[）)]?',
      multiLine: true,
    );
    final allCmd = RegExp(
      r'(すべて選びなさい|全て選びなさい|すべて選べ|全て選べ)',
      multiLine: true,
    );

    // 2) 末尾や文中にある上記表現を削除（余計な空白や句点を整理）
    String out = q.replaceAll(baseCountCmd, '');
    out = out.replaceAll(allCmd, '');

    // 連続スペースや句読点＋スペースを軽く整形
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    out = out.replaceAll(RegExp(r'。\s*$'), '。').trim();

    // 3) 統一表現を1回だけ付与（かっこ無しで統一）
    //   例: 「 … 2つ選んでください」
    return '$out ${requiredCorrectCount}つ選んでください';
  }

  static String _firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    return (t.length <= maxChars) ? t : t.substring(0, maxChars) + '...';
  }
}