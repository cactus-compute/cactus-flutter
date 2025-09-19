import 'dart:convert';
import 'dart:io';
import 'package:cactus/models/types.dart';
import 'package:flutter/foundation.dart';

class OpenRouterService {
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'qwen/qwen-2.5-7b-instruct';
  final String apiKey;
  final HttpClient _httpClient;

  OpenRouterService({required this.apiKey}) : _httpClient = HttpClient();

  /// Generate completion using OpenRouter API
  Future<CactusCompletionResult> generateCompletion({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final requestBody = {
        'model': defaultModel,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'temperature': params?.temperature ?? 0.1,
        'max_tokens': params?.maxTokens ?? 200,
        'top_p': params?.topP ?? 0.95,
        'stop': params?.stopSequences ?? [],
      };

      final response = await _makeRequest('/chat/completions', requestBody);
      stopwatch.stop();

      if (response['choices'] == null || response['choices'].isEmpty) {
        throw Exception('No choices returned from OpenRouter API');
      }

      final choice = response['choices'][0];
      final content = choice['message']?['content'] ?? '';
      final usage = response['usage'] ?? {};

      return CactusCompletionResult(
        success: true,
        response: content,
        timeToFirstTokenMs: stopwatch.elapsedMilliseconds.toDouble(),
        totalTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        tokensPerSecond: _calculateTokensPerSecond(usage['total_tokens'] ?? 0, stopwatch.elapsedMilliseconds),
        prefillTokens: usage['prompt_tokens'] ?? 0,
        decodeTokens: usage['completion_tokens'] ?? 0,
        totalTokens: usage['total_tokens'] ?? 0,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('OpenRouter API error: $e');
      return CactusCompletionResult(
        success: false,
        response: 'OpenRouter API error: $e',
        timeToFirstTokenMs: stopwatch.elapsedMilliseconds.toDouble(),
        totalTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        tokensPerSecond: 0.0,
        prefillTokens: 0,
        decodeTokens: 0,
        totalTokens: 0,
      );
    }
  }

  Future<Map<String, dynamic>> _makeRequest(String endpoint, Map<String, dynamic> body) async {
    final request = await _httpClient.postUrl(Uri.parse('$baseUrl$endpoint'));
    
    request.headers.add('Authorization', 'Bearer $apiKey');
    request.headers.add('Content-Type', 'application/json');
    request.headers.add('HTTP-Referer', 'https://cactuscompute.com');
    request.headers.add('X-Title', 'Cactus Flutter SDK');

    request.write(jsonEncode(body));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $responseBody');
    }

    return jsonDecode(responseBody);
  }

  double _calculateTokensPerSecond(int totalTokens, int elapsedMs) {
    if (elapsedMs == 0) return 0.0;
    return (totalTokens * 1000.0) / elapsedMs;
  }

  void dispose() {
    _httpClient.close();
  }
}