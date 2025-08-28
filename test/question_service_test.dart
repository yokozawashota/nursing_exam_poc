import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nursing_exam_poc/services/question_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuestionService.fetchQuestion', () {
    test('APIキー未設定なら例外', () async {
      SharedPreferences.setMockInitialValues({}); // キー無し
      expect(
            () => QuestionService.fetchQuestion(
          difficulty: '必修問題',
          category: '成人看護学',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('モックHTTPで正常なJSONをパースできる', () async {
      // 擬似的にAPIキー/モデルを保存
      SharedPreferences.setMockInitialValues({
        'OPENAI_API_KEY': 'test-key',
        'OPENAI_MODEL': 'gpt-3.5-turbo',
      });

      // OpenAIのレスポンスを模したモック
      final mockResponseJson = {
        "choices": [
          {
            "message": {
              "content": jsonEncode({
                "question": "心拍出量に影響を与える因子として最も重要なのはどれか？",
                "choices": {
                  "A": "前負荷",
                  "B": "後負荷",
                  "C": "心拍数",
                  "D": "心筋収縮力"
                },
                "answer": "D",
                "explanation": "心拍出量は特に心筋収縮力と心拍数に強く影響される。",
                "rationales": {
                  "A": "重要だが今回は主因ではない",
                  "B": "状況により影響するが最重要ではない",
                  "C": "影響するが今回は主因ではない",
                  "D": "最も重要な因子である"
                }
              }),
            }
          }
        ]
      };

      final client = MockClient((http.Request req) async {
        return http.Response(jsonEncode(mockResponseJson), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final result = await QuestionService.fetchQuestion(
        difficulty: '一般問題',
        category: '成人看護学',
        httpClient: client, // ★ モック注入
      );

      expect(result['question'], isA<String>());
      expect(result['question'], isNotEmpty);
      expect(result['choices'], isA<Map<String, String>>());
      expect((result['choices'] as Map).length, 4);
      expect(result['answer'], anyOf('A', 'B', 'C', 'D'));
      expect(result['rationales'], isA<Map<String, String>>());
    });
  });
}