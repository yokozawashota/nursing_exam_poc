// lib/services/response_parser.dart
import 'dart:convert';

import 'choice_normalizer.dart';    // 既存：選択肢の正規化（配列/マップ、index/letter混在を標準形へ）
import '../utils/choice_logic.dart'; // 新規：シャッフル／再ラベル／4択制限

/// OpenAI の message.content （文字列）から、
/// 画面層がそのまま使える {question, choices, correct, explanation, rationales?, meta} を返す。
class ResponseParser {
  /// API応答の message.content（JSON文字列 or それを含むテキスト）を標準化マップへ変換
  static Map<String, dynamic> parseContentToQuestion(
      String content, {
        required String difficulty,
        required String domain,
        required String major,
        String? mid,
        String? topic,
      }) {
    // 1) JSONを抽出
    final jsonOut = _extractJson(content);

    // 2) question を確実に取得
    final String question = _pickString(jsonOut, ['question', 'questionText', 'text']).trim();
    if (question.isEmpty) {
      throw StateError('生成結果が不完全です（question が空）');
    }

    // 3) choices / correct を正規化（既存ユーティリティに任せる）
    final normalized = ChoiceNormalizer.normalize(jsonOut); // 型は dynamic で受けてもOK

    // 4) 正規化された items から元の A.. ラベルを一旦振る
    const letters = ['A','B','C','D','E','F','G','H'];
    final Map<String, String> originalChoices = {};
    final Map<String, String> originalRationales = {};
    String? originalCorrectLabel;

    // normalized.items は {text, rationale?, isCorrect?} を想定
    for (var i = 0; i < normalized.items.length && i < letters.length; i++) {
      final label = letters[i];
      final item  = normalized.items[i];
      final text  = (item.text ?? '').toString();
      if (text.trim().isEmpty) continue;

      originalChoices[label] = text;

      final rationale = (item.rationale?.toString() ?? '').trim();
      if (rationale.isNotEmpty) {
        originalRationales[label] = rationale;
      }
      if (item.isCorrect == true) {
        originalCorrectLabel = label;
      }
    }
    originalCorrectLabel ??= originalChoices.keys.isNotEmpty ? originalChoices.keys.first : 'A';

    // 5) 要素単位でシャッフルし、新しい A.. ラベルを振り直す（正答も追随）
    final shuffled = ChoiceLogic.shuffleWithRelabel(
      originalChoices,
      originalCorrectLabel,
      rationales: originalRationales,
    );

    // 6) 念のため 2〜4択に制限（UIは存在キーのみ描画）
    final limitedChoices = ChoiceLogic.limitTo4(shuffled.choices);
    final limitedRationales = Map.fromEntries(
      shuffled.rationales.entries.where((e) => limitedChoices.containsKey(e.key)),
    );

    // 7) 解説
    final String explanation = _pickString(jsonOut, ['explanation', 'reason', '解説']).trim();

    // 8) 画面が期待する形で返す
    return <String, dynamic>{
      'question'    : question,
      'choices'     : limitedChoices,         // Map<String, String>（A〜D）
      'correct'     : shuffled.correctLabel,  // 'A' | 'B' | 'C' | 'D'
      'explanation' : explanation,
      if (limitedRationales.isNotEmpty) 'rationales': limitedRationales,
      'meta': {
        'difficulty': difficulty,
        'domain'    : domain,
        'major'     : major,
        'mid'       : mid,
        'topic'     : topic,
      }
    };
  }

  /// content から JSON オブジェクトを取り出す（素直に decode できない場合に備えた後方互換）
  static Map<String, dynamic> _extractJson(String content) {
    try {
      final obj = jsonDecode(content) as Map<String, dynamic>;
      return obj;
    } catch (_) {
      // テキストに JSON が混ざっている場合：最初の {...} を抜き出す
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (m != null) {
        return jsonDecode(m.group(0)!) as Map<String, dynamic>;
      }
      throw StateError('JSON抽出に失敗: $content');
    }
  }

  static String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return '';
  }
}