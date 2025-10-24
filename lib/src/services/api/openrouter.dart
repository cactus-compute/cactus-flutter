import 'dart:async';
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

  Future<CactusStreamedCompletionResult> generateCompletionStream({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
  }) async {
    final requestBody = {
      'model': defaultModel,
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'temperature': params?.temperature ?? 0.1,
      'max_tokens': params?.maxTokens ?? 200,
      'top_p': params?.topP ?? 0.95,
      'stop': params?.stopSequences ?? [],
      'stream': true,
    };

    final request = await _httpClient.postUrl(Uri.parse('$baseUrl/chat/completions'));
    request.headers.add('Authorization', 'Bearer $apiKey');
    request.headers.add('Content-Type', 'application/json');
    request.headers.add('HTTP-Referer', 'https://cactuscompute.com');
    request.headers.add('X-Title', 'Cactus Flutter SDK');

    request.write(jsonEncode(requestBody));

    final response = await request.close();

    if (response.statusCode != 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}: $responseBody');
    }

    final streamController = StreamController<String>();
    final completer = Completer<CactusCompletionResult>();
    final stopwatch = Stopwatch()..start();

    String fullResponse = "";
    int promptTokens = 0;
    int completionTokens = 0;
    int totalTokens = 0;
    double timeToFirstTokenMs = 0;

    response.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        if (line.startsWith('data: ')) {
          final dataString = line.substring(6);
          if (dataString == '[DONE]') {
            stopwatch.stop();
            final result = CactusCompletionResult(
              success: true,
              response: fullResponse,
              timeToFirstTokenMs: timeToFirstTokenMs,
              totalTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
              tokensPerSecond: _calculateTokensPerSecond(totalTokens, stopwatch.elapsedMilliseconds),
              prefillTokens: promptTokens,
              decodeTokens: completionTokens,
              totalTokens: totalTokens,
            );
            if (!completer.isCompleted) completer.complete(result);
            if (!streamController.isClosed) streamController.close();
            return;
          }
          try {
            final data = jsonDecode(dataString);
            final choice = data['choices'][0];

            if (choice['delta'] != null && choice['delta']['content'] != null) {
              if (timeToFirstTokenMs == 0) {
                timeToFirstTokenMs = stopwatch.elapsedMilliseconds.toDouble();
              }
              final content = choice['delta']['content'];
              streamController.add(content);
              fullResponse += content;
            }

            if (data['usage'] != null) {
              promptTokens = data['usage']['prompt_tokens'] ?? 0;
              completionTokens = data['usage']['completion_tokens'] ?? 0;
              totalTokens = data['usage']['total_tokens'] ?? 0;
            }
          } catch (e) {
            debugPrint('Error parsing stream data: $e, data: $dataString');
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) completer.completeError(error);
        if (!streamController.isClosed) {
          streamController.addError(error);
          streamController.close();
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          stopwatch.stop();
          final result = CactusCompletionResult(
            success: fullResponse.isNotEmpty,
            response: fullResponse,
            timeToFirstTokenMs: timeToFirstTokenMs,
            totalTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
            tokensPerSecond: _calculateTokensPerSecond(totalTokens, stopwatch.elapsedMilliseconds),
            prefillTokens: promptTokens,
            decodeTokens: completionTokens,
            totalTokens: totalTokens,
          );
          completer.complete(result);
        }
        if (!streamController.isClosed) streamController.close();
      },
    );

    return CactusStreamedCompletionResult(
      stream: streamController.stream,
      result: completer.future,
    );
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