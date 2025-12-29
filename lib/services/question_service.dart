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
import '../models/nurai_question.dart';

class QuestionService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  /// ✅ 新メソッド（モデル直返し）
  /// AIから問題を取得し、そのまま NuraiQuestion モデルに変換して返す。
  /// ※ NuraiQuestion.fromAi は使わない（存在しないため）
  static Future<NuraiQuestion> fetchNuraiQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,
  }) async {
    // 既存の fetchQuestion を利用（Mapを返す）
    final raw = await fetchQuestion(
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: mid,
      scenarioAspect: scenarioAspect,
    );

    // raw(Map) → NuraiQuestion に変換（後方互換も少しだけ考慮）
    final Map<String, String> choices =
    (raw['choices'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v'));

    final List<String> correctLabels =
    ((raw['correctAnswers'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    final Map<String, String>? rationales =
    (raw['rationales'] as Map?)?.map((k, v) => MapEntry('$k', '$v'));

    final String questionText =
    (raw['question'] ?? raw['questionText'] ?? '').toString();

    final String kind = (raw['questionKind'] ?? 'single').toString();

    final int requiredCorrectCount =
        (raw['requiredCorrectCount'] as int?) ??
            correctLabels.length.clamp(1, choices.length);

    // ★ sourceTag は NuraiQuestion 側で required（null不可）なのでフォールバック必須
    final String sourceTag = (raw['sourceTag']?.toString().trim() ?? '');
    final String fixedSourceTag = sourceTag.isNotEmpty
        ? sourceTag
        : 'ai:${DateTime.now().millisecondsSinceEpoch}';

    // ★ 画像関連（AI生成は基本なし。将来rawに入れるならここで拾える）
    final String? imagePath = raw['imagePath']?.toString();
    final bool imageRequired =
        (raw['imageRequired'] == true) || ((imagePath ?? '').trim().isNotEmpty && raw['imageRequired'] == true);

    return NuraiQuestion(
      questionText: questionText,
      backgroundText: raw['backgroundText']?.toString() ??
          raw['background']?.toString() ??
          raw['context']?.toString() ??
          raw['scenario']?.toString() ??
          raw['scenarioText']?.toString(),
      choices: choices,
      correctLabels: correctLabels,
      choiceRationales: rationales,
      explanation: raw['explanation']?.toString(),
      questionKind: kind,
      requiredCorrectCount: requiredCorrectCount,
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: raw['mid']?.toString(),
      topic: raw['topic']?.toString(),
      sourceType: 'ai',
      sourceTag: fixedSourceTag,
      imagePath: (imagePath ?? '').trim().isEmpty ? null : imagePath,
      imageRequired: imageRequired, // ★ required なので必ず渡す
    );
  }

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
            mid: resolvedMid!,
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

    // ===== content の安全な抽出 =====
    final Map<String, dynamic> root =
    jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List choicesRoot = (root['choices'] as List? ?? const []);
    final String content = choicesRoot.isNotEmpty
        ? (choicesRoot.first['message']?['content']?.toString() ?? '')
        : '';

    debugPrint('[log] [QS] raw content (head) = ${_firstLines(content)}');

    // ===== パース & 最終整形 =====
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
      // 1) 正答が choices に含まれない場合の安全弁
      final present = choices.keys.toSet();
      final filtered = correct.where(present.contains).toList();
      out['correctAnswers'] = filtered.isNotEmpty
          ? filtered
          : (choices.isNotEmpty ? [choices.keys.first] : []);

      // 2) 問題文に「nつ選んでください」を付与（multiple/select_incorrect のとき）
      final isMulti = desiredKind == 'multiple' || desiredKind == 'select_incorrect';
      final q = (out['question'] as String? ?? '').trim();
      out['question'] = _ensureCountInstruction(
        q,
        isMulti: isMulti,
        requiredCorrectCount: requiredCorrectCount,
      );

      // 3) ★ 正答位置を完全ランダム化（毎回シャッフル）
      final remapped = _remapChoicesRandom(
        originalChoices: (out['choices'] as Map).cast<String, String>(),
        originalCorrectLabels: (out['correctAnswers'] as List).cast<String>(),
        originalRationales: (out['rationales'] as Map?)?.cast<String, String>(),
      );

      debugPrint(
        '[log] [QS] before shuffle => kind=${out['questionKind']}, '
            'choices=${choices.keys.join(',')} (len=${choices.length}), '
            'correct=${correct.join(',')}',
      );
      debugPrint(
        '[log] [QS] after shuffle  => kind=${out['questionKind']}, '
            'choices=${remapped.choices.keys.join(',')} '
            '(len=${remapped.choices.length}), '
            'correct=${remapped.corrects.join(',')}',
      );

      out['choices'] = remapped.choices; // 新しいラベル順（A..）
      out['correctAnswers'] = remapped.corrects; // 新しい正答ラベル
      if (remapped.rationales != null) {
        out['rationales'] = remapped.rationales; // 根拠も同じ順番に付け替え
      }
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

    final already =
    RegExp(r'[0-9一二三四五六七八九十]+\s*つ\s*選んでください').hasMatch(q);
    if (already) return q;

    return '$q ${requiredCorrectCount}つ選んでください';
  }

  static String _firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    return (t.length <= maxChars) ? t : '${t.substring(0, maxChars)}...';
  }
}

// ===== 内部モデル（返却用）=====
class _RemapResult {
  final Map<String, String> choices;
  final List<String> corrects;
  final Map<String, String>? rationales;
  _RemapResult(this.choices, this.corrects, this.rationales);
}

// ===== 正答位置を完全ランダム化 =====
_RemapResult _remapChoicesRandom({
  required Map<String, String> originalChoices,
  required List<String> originalCorrectLabels,
  Map<String, String>? originalRationales,
}) {
  // 既存ラベルの並び（A..Eのうち存在するものだけ）
  final labels = ['A', 'B', 'C', 'D', 'E'].where(originalChoices.containsKey).toList();
  final n = labels.length;
  if (n <= 1) {
    return _RemapResult(
      Map<String, String>.from(originalChoices),
      List<String>.from(originalCorrectLabels),
      originalRationales == null ? null : Map<String, String>.from(originalRationales),
    );
  }

  final rng = Random(DateTime.now().microsecondsSinceEpoch);

  // (label, text) のエントリ配列を作ってシャッフル
  final entries = <MapEntry<String, String>>[
    for (final k in labels) MapEntry(k, originalChoices[k]!)
  ]..shuffle(rng);

  final originalCorrectSet = originalCorrectLabels.toSet();

  final newChoices = <String, String>{};
  final newCorrects = <String>[];
  Map<String, String>? newRationales = originalRationales != null ? <String, String>{} : null;

  for (var i = 0; i < entries.length; i++) {
    final newLabel = String.fromCharCode('A'.codeUnitAt(0) + i);
    final e = entries[i]; // e.key = 旧ラベル, e.value = 選択肢文

    newChoices[newLabel] = e.value;

    // 正答だった旧ラベルは、新しいラベルを正答に付け替える
    if (originalCorrectSet.contains(e.key)) {
      newCorrects.add(newLabel);
    }

    // rationales も 旧ラベル→新ラベルに写し替える
    if (newRationales != null && originalRationales != null) {
      final r = originalRationales[e.key];
      if (r != null && r.isNotEmpty) {
        newRationales[newLabel] = r;
      }
    }
  }

  return _RemapResult(
    newChoices,
    newCorrects,
    newRationales ?? originalRationales,
  );
}