// lib/questioning/services/openai_chat_client.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class OpenAiChatClient {
  OpenAiChatClient({
    http.Client? httpClient,
    String? endpoint,
  })  : _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? 'https://api.openai.com/v1/chat/completions';

  final http.Client _http;
  final String _endpoint;

  Future<OpenAiChatResult> createJsonObjectCompletion({
    required String apiKey,
    required String model,
    required String system,
    required String user,
    double temperature = 0.4,
  }) async {
    final reqMap = {
      'model': model,
      'temperature': temperature,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };

    final reqBody = jsonEncode(reqMap);

    final res = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: reqBody,
    );

    final Uint8List bytes = res.bodyBytes;
    final decodedBody = utf8.decode(bytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw OpenAiHttpException(
        statusCode: res.statusCode,
        body: decodedBody,
      );
    }

    final Map<String, dynamic> root = jsonDecode(decodedBody) as Map<String, dynamic>;
    final List choicesRoot = (root['choices'] as List? ?? const []);
    final String content = choicesRoot.isNotEmpty
        ? (choicesRoot.first['message']?['content']?.toString() ?? '')
        : '';

    return OpenAiChatResult(
      requestBody: reqBody,
      responseBody: decodedBody,
      content: content,
    );
  }
}

class OpenAiChatResult {
  final String requestBody;
  final String responseBody;
  final String content;
  OpenAiChatResult({
    required this.requestBody,
    required this.responseBody,
    required this.content,
  });
}

class OpenAiHttpException implements Exception {
  final int statusCode;
  final String body;
  OpenAiHttpException({required this.statusCode, required this.body});

  @override
  String toString() => 'OpenAI request failed ($statusCode): $body';
}