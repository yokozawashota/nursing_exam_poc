// lib/questioning/services/question_service.dart
//
// QuestionService
// ================================
//
// ■ 役割
// Questioningレイヤーにおける「問題生成オーケストレーター」。
// UI層や QuestionEngine から呼ばれ、問題生成フロー全体を調停する。
// 自身は具体的ロジックをほぼ持たず、各専用サービスへ委譲する。
//
// ■ 現在の責務
// - APIキー / モデル取得
// - 出題形式決定（resolver呼び出し）
// - mid / topic 決定（resolver呼び出し）
// - prompt生成
// - OpenAI呼び出し
// - LLMレスポンスのパース
// - 最終安全化処理
// - Map形式 or NuraiQuestion形式で返却
//
// ■ 実際の処理担当
//
// 出題形式決定
//   → question_generation_options_resolver.dart
//
// mid / topic 決定
//   → question_topic_resolver.dart
//
// prompt生成
//   → prompt_builder.dart
//
// OpenAI HTTP
//   → openai_chat_client.dart
//
// LLMレスポンス整形
//   → response_parser.dart
//
// 最終安全化
//   → question_post_processor.dart
//
// ■ 将来構造
// QuestionEngine が生成司令塔になり、
// QuestionService は「LLM生成サービス」としてさらに薄くなる想定。
//

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/past_exam/models/past_exam_question.dart';
import '../../features/settings/services/settings_service.dart';

import 'openai_chat_client.dart';
import 'prompt_builder.dart';
import 'question_generation_options_resolver.dart';
import 'question_post_processor.dart';
import 'question_topic_resolver.dart';
import 'response_parser.dart';

class QuestionService {
  static final OpenAiChatClient _chatClient = OpenAiChatClient();

  /// PastExam(NuraiQuestion)向け互換ラッパ
  ///
  /// LLM生成結果(Map)を NuraiQuestion へ変換する。
  /// practice / mock / past_exam 互換維持のため存在。
  static Future<NuraiQuestion> fetchNuraiQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,
  }) async {
    final raw = await fetchQuestion(
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: mid,
      scenarioAspect: scenarioAspect,
    );

    final choices =
    (raw['choices'] as Map? ?? const {}).map((k, v) => MapEntry('$k', '$v'));

    final correctLabels = ((raw['correctAnswers'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();

    final rationales =
    (raw['rationales'] as Map?)?.map((k, v) => MapEntry('$k', '$v'));

    final questionText =
    (raw['question'] ?? raw['questionText'] ?? '').toString();
    final kind = (raw['questionKind'] ?? 'single').toString();

    final requiredCorrectCount = (raw['requiredCorrectCount'] is int)
        ? raw['requiredCorrectCount'] as int
        : correctLabels.length.clamp(1, choices.length);

    final sourceTag = (raw['sourceTag']?.toString().trim() ?? '');
    final fixedSourceTag =
    sourceTag.isNotEmpty ? sourceTag : 'ai:${DateTime.now().millisecondsSinceEpoch}';

    final imagePath = raw['imagePath']?.toString();
    final imageRequired = raw['imageRequired'] == true;

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
      imageRequired: imageRequired,
    );
  }

  /// 生成結果を Map として返す（practice / mock 互換）
  static Future<Map<String, dynamic>> fetchQuestion({
    required String difficulty,
    required String domain,
    required String major,
    String? mid,
    String? scenarioAspect,
  }) async {
    final swTotal = Stopwatch()..start();

    int tSettingsMs = 0;
    int tPickMs = 0;
    int tPromptMs = 0;
    int tHttpMs = 0;
    int tDecodeMs = 0;
    int tParseMs = 0;
    int tPostMs = 0;

    int lenSystem = 0;
    int lenUser = 0;
    int lenRequestBody = 0;
    int lenResponseBody = 0;
    int lenContent = 0;

    String resolvedMidForLog = '';
    String topicForLog = '';

    // ===== APIキー / モデル取得 =====
    final apiKey = await SettingsService.getApiKey();
    final model = await SettingsService.getModel() ?? 'gpt-4o-mini';

    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('OpenAI APIキーが未設定です。設定画面から入力してください。');
    }

    // ===== 出題形式決定 =====
    final swSettings = Stopwatch()..start();

    final options = await QuestionGenerationOptionsResolver.resolve();

    swSettings.stop();
    tSettingsMs = swSettings.elapsedMilliseconds;

    debugPrint(
      '[log] [SETTINGS] ChoiceMode=${options.choiceMode} | '
          '5択確率=${options.probFiveChoice}% | '
          '複数選択確率=${options.probMultiple}% | '
          '誤答確率=${options.probIncorrect}%',
    );

    debugPrint(
      '[log] [QS] desiredChoiceCount=${options.desiredChoiceCount} | '
          'requiredCorrectCount=${options.requiredCorrectCount} | '
          'desiredKind=${options.desiredKind}',
    );

    // ===== mid / topic 決定 =====
    final swPick = Stopwatch()..start();

    final topicResolution = await QuestionTopicResolver.resolve(
      domain: domain,
      major: major,
      mid: mid,
    );

    swPick.stop();
    tPickMs = swPick.elapsedMilliseconds;

    final resolvedMid = topicResolution.resolvedMid;
    final topic = topicResolution.topic;

    resolvedMidForLog = (resolvedMid ?? '').trim();
    topicForLog = (topic ?? '').trim();

    // ===== プロンプト生成 =====
    final swPrompt = Stopwatch()..start();

    final system = PromptBuilder.buildSystemPrompt(
      desiredKind: options.desiredKind,
      desiredChoiceCount: options.desiredChoiceCount,
      requiredCorrectCount: options.requiredCorrectCount,
    );

    final user = PromptBuilder.buildUserPrompt(
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: resolvedMid,
      topic: topic,
      scenarioAspect: scenarioAspect,
      desiredKind: options.desiredKind,
      desiredChoiceCount: options.desiredChoiceCount,
      requiredCorrectCount: options.requiredCorrectCount,
    );

    swPrompt.stop();
    tPromptMs = swPrompt.elapsedMilliseconds;

    lenSystem = system.length;
    lenUser = user.length;

    // ===== LLM 呼び出し =====
    final swHttp = Stopwatch()..start();

    String content = '';

    try {
      final result = await _chatClient.createJsonObjectCompletion(
        apiKey: apiKey,
        model: model,
        system: system,
        user: user,
        temperature: 0.4,
      );

      swHttp.stop();
      tHttpMs = swHttp.elapsedMilliseconds;

      lenRequestBody = result.requestBody.length;
      lenResponseBody = result.responseBody.length;

      content = result.content;
      lenContent = content.length;
    } on OpenAiHttpException catch (e) {
      swHttp.stop();
      tHttpMs = swHttp.elapsedMilliseconds;

      swTotal.stop();

      final bodyPreview = _firstLines(e.body, maxChars: 240);

      debugPrint(
        '[perf] [QS] FAIL status=${e.statusCode} total=${swTotal.elapsedMilliseconds}ms | '
            'settings=${tSettingsMs}ms pick=${tPickMs}ms prompt=${tPromptMs}ms http=${tHttpMs}ms',
      );

      debugPrint('[perf] [QS] FAIL response(head)=$bodyPreview');

      throw StateError('OpenAIリクエスト失敗 (${e.statusCode}): ${e.body}');
    }

    // ===== content 抽出ログ =====
    final swDecode = Stopwatch()..start();
    swDecode.stop();
    tDecodeMs = swDecode.elapsedMilliseconds;

    debugPrint('[log] [QS] raw content (head) = ${_firstLines(content)}');

    // ===== LLMレスポンス解析 =====
    final swParse = Stopwatch()..start();

    final parsed = ResponseParser.parseContentToQuestion(
      content,
      difficulty: difficulty,
      domain: domain,
      major: major,
      mid: resolvedMid,
      topic: topic,
    );

    swParse.stop();
    tParseMs = swParse.elapsedMilliseconds;

    // ===== 最終安全化 =====
    final swPost = Stopwatch()..start();

    final out = QuestionPostProcessor.process(
      parsed: parsed,
      desiredKind: options.desiredKind,
      requiredCorrectCount: options.requiredCorrectCount,
    );

    swPost.stop();
    tPostMs = swPost.elapsedMilliseconds;

    debugPrint(
      '[log] [QS] parsed => kind=${out['questionKind']}, '
          'choices=${(out['choices'] as Map?)?.keys.join(',') ?? ''} '
          '(len=${(out['choices'] as Map?)?.length ?? 0}), '
          'correct=${(out['correctAnswers'] as List?)?.join(',') ?? ''}',
    );

    swTotal.stop();

    int outJsonLen;

    try {
      outJsonLen = jsonEncode(out).length;
    } catch (_) {
      outJsonLen = -1;
    }

    debugPrint(
      '[perf] [QS] OK total=${swTotal.elapsedMilliseconds}ms | '
          'settings=${tSettingsMs}ms pick=${tPickMs}ms prompt=${tPromptMs}ms '
          'http=${tHttpMs}ms decode=${tDecodeMs}ms parse=${tParseMs}ms post=${tPostMs}ms',
    );

    debugPrint(
      '[perf] [QS] meta model=$model diff=$difficulty domain=$domain major=$major '
          'mid=${resolvedMidForLog.isEmpty ? "-" : resolvedMidForLog} '
          'topic=${topicForLog.isEmpty ? "-" : topicForLog} '
          'kind=${options.desiredKind} choices=${options.desiredChoiceCount} '
          'correctN=${options.requiredCorrectCount}',
    );

    debugPrint(
      '[perf] [QS] size system=$lenSystem user=$lenUser reqBody=$lenRequestBody '
          'resBody=$lenResponseBody content=$lenContent outJson=$outJsonLen',
    );

    return out;
  }

  static String _firstLines(String s, {int maxChars = 300}) {
    final t = s.replaceAll('\n', ' ');
    return (t.length <= maxChars) ? t : '${t.substring(0, maxChars)}...';
  }
}