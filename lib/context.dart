import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import './bindings.dart' as bindings;
import './types.dart';

class CactusContext {
  static String _escapeJsonString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  static Future<int?> initContext(String modelPath, {int contextSize = 2048}) async {
    try {
      debugPrint('Initializing context with model: $modelPath, contextSize: $contextSize');
      final modelPathC = modelPath.toNativeUtf8(allocator: calloc);
      try {
        final handle = bindings.cactusInit(modelPathC, contextSize);
        if (handle != nullptr) {
          debugPrint('Context initialized successfully');
          return handle.address;
        } else {
          debugPrint('Failed to initialize context');
          return null;
        }
      } finally {
        calloc.free(modelPathC);
      }
    } catch (e) {
      debugPrint('Exception during context initialization: $e');
      return null;
    }
  }

  static void freeContext(int handle) {
    try {
      bindings.cactusDestroy(Pointer.fromAddress(handle));
      debugPrint('Context destroyed');
    } catch (e) {
      debugPrint('Error destroying context: $e');
    }
  }

  static Future<CactusCompletionResult> completion(
    int handle,
    List<ChatMessage> messages,
    CactusCompletionParams params,
  ) async {
    final messagesJsonBuffer = StringBuffer('[');
    for (int i = 0; i < messages.length; i++) {
      if (i > 0) messagesJsonBuffer.write(',');
      messagesJsonBuffer.write('{');
      messagesJsonBuffer.write('"role":"${messages[i].role}",');
      messagesJsonBuffer.write('"content":"${_escapeJsonString(messages[i].content)}"');
      messagesJsonBuffer.write('}');
    }
    messagesJsonBuffer.write(']');
    final messagesJson = messagesJsonBuffer.toString();

    final optionsJsonBuffer = StringBuffer('{');
    optionsJsonBuffer.write('"temperature":${params.temperature},');
    optionsJsonBuffer.write('"top_k":${params.topK},');
    optionsJsonBuffer.write('"top_p":${params.topP},');
    optionsJsonBuffer.write('"max_tokens":${params.maxTokens}');
    if (params.stopSequences.isNotEmpty) {
      optionsJsonBuffer.write(',"stop":[');
      for (int i = 0; i < params.stopSequences.length; i++) {
        if (i > 0) optionsJsonBuffer.write(',');
        optionsJsonBuffer.write('"${_escapeJsonString(params.stopSequences[i])}"');
      }
      optionsJsonBuffer.write(']');
    }
    optionsJsonBuffer.write('}');
    final optionsJson = optionsJsonBuffer.toString();

    final responseBuffer = calloc<Uint8>(params.bufferSize);
    final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);
    final optionsJsonC = optionsJson.toNativeUtf8(allocator: calloc);

    try {
      final result = bindings.cactusComplete(
        Pointer.fromAddress(handle),
        messagesJsonC,
        responseBuffer.cast<Utf8>(),
        params.bufferSize,
        optionsJsonC,
      );

      debugPrint('Received completion result code: $result');

      if (result > 0) {
        final responseText = responseBuffer.cast<Utf8>().toDartString().trim();
        
        try {
          final jsonResponse = jsonDecode(responseText) as Map<String, dynamic>;
          final success = jsonResponse['success'] as bool? ?? true;
          final response = jsonResponse['response'] as String? ?? responseText;
          final timeToFirstTokenMs = (jsonResponse['time_to_first_token_ms'] as num?)?.toDouble() ?? 0.0;
          final totalTimeMs = (jsonResponse['total_time_ms'] as num?)?.toDouble() ?? 0.0;
          final tokensPerSecond = (jsonResponse['tokens_per_second'] as num?)?.toDouble() ?? 0.0;
          final prefillTokens = jsonResponse['prefill_tokens'] as int? ?? 0;
          final decodeTokens = jsonResponse['decode_tokens'] as int? ?? 0;
          final totalTokens = jsonResponse['total_tokens'] as int? ?? 0;

          return CactusCompletionResult(
            success: success,
            response: response,
            timeToFirstTokenMs: timeToFirstTokenMs,
            totalTimeMs: totalTimeMs,
            tokensPerSecond: tokensPerSecond,
            prefillTokens: prefillTokens,
            decodeTokens: decodeTokens,
            totalTokens: totalTokens,
          );
        } catch (e) {
          debugPrint('Unable to parse the response json: $e');
          return CactusCompletionResult(
            success: false,
            response: 'Error: Unable to parse the response',
            timeToFirstTokenMs: 0.0,
            totalTimeMs: 0.0,
            tokensPerSecond: 0.0,
            prefillTokens: 0,
            decodeTokens: 0,
            totalTokens: 0,
          );
        }
      } else {
        return CactusCompletionResult(
          success: false,
          response: 'Error: completion failed with code $result',
          timeToFirstTokenMs: 0.0,
          totalTimeMs: 0.0,
          tokensPerSecond: 0.0,
          prefillTokens: 0,
          decodeTokens: 0,
          totalTokens: 0,
        );
      }
    } finally {
      calloc.free(responseBuffer);
      calloc.free(messagesJsonC);
      calloc.free(optionsJsonC);
    }
  }
}