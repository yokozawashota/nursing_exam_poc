// lib/ai_analysis/classification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/settings_service.dart';

/// ----------------------------------------------
/// LLMによる major / mid / topic 自動推定サービス
/// ----------------------------------------------
class ClassificationService {
  /// OpenAI API に問い合わせて、科目 / 中項目 / トピックを推定する
  /// 返却形式は {"major": "...", "mid": "...", "topic": "..."} を保証
  static Future<Map<String, String>> classifyStructure({
    required String question,
    required String difficulty,
  }) async {
    // ★ SettingsService は static メソッドで呼び出す
    final apiKey = await SettingsService.getApiKey();
    final model = await SettingsService.getModel();

    // APIキー or モデルが未設定ならフォールバック
    if (apiKey == null ||
        apiKey.isEmpty ||
        model == null ||
        model.isEmpty) {
      return _fallback();
    }

    // ---- プロンプト定義 ----
    final systemPrompt = """
あなたは看護師国家試験の出題分類に精通した専門家です。

入力される問題文に対して、以下の３分類を必ず１つずつ返してください：

1. major（科目）  
2. mid（中項目）  
3. topic（トピック名：20文字以内の簡潔な名前）

返却形式は必ず JSON のみ：
{
  "major": "...",
  "mid": "...",
  "topic": "..."
}

必修問題の場合も、必ず major / mid / topic を推定してください。
推定が難しい場合は、必ず以下を使用してください：

- major: "必修（基礎）"
- mid: "未分類"
- topic: "未分類"
""";

    final userPrompt = """
【問題文】
$question

【形式】
$difficulty

上記の問題を分類してください。
""";

    try {
      final res = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": model,
          "temperature": 0.1,
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt},
          ],
        }),
      );

      if (res.statusCode != 200) {
        return _fallback();
      }

      final json = jsonDecode(res.body);
      final content = json["choices"][0]["message"]["content"];

      // 返ってくる content は JSON 文字列前提
      final map = jsonDecode(content);

      return {
        "major": (map["major"] ?? "未分類").toString(),
        "mid": (map["mid"] ?? "未分類").toString(),
        "topic": (map["topic"] ?? "未分類").toString(),
      };
    } catch (_) {
      return _fallback();
    }
  }

  /// 推論に失敗した場合の代替値
  static Map<String, String> _fallback() {
    return {
      "major": "未分類",
      "mid": "未分類",
      "topic": "未分類",
    };
  }
}