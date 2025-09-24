import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cactus/models/types.dart';
import 'package:cactus/models/tools.dart';
import 'package:cactus/src/models/binding.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'bindings.dart' as bindings;

// Global callback storage for streaming completions
CactusTokenCallback? _activeTokenCallback;

// Static callback function that can be used with Pointer.fromFunction
@pragma('vm:entry-point')
void _staticTokenCallbackDispatcher(Pointer<Utf8> tokenC, int tokenId, Pointer<Void> userData) {
  try {
    final callback = _activeTokenCallback;
    if (callback != null) {
      final tokenString = tokenC.toDartString();
      callback(tokenString);
    }
  } catch (e) {
    debugPrint('Token callback error: $e');
  }
}

Future<(int?, String)> _initContextInIsolate(Map<String, dynamic> params) async {
  final modelPath = params['modelPath'] as String;
  final contextSize = params['contextSize'] as int;

  try {
    debugPrint('Initializing context with model: $modelPath, contextSize: $contextSize');
    final modelPathC = modelPath.toNativeUtf8(allocator: calloc);
    try {
      final handle = bindings.cactusInit(modelPathC, contextSize);
      if (handle != nullptr) {
        return (handle.address, 'Context initialized successfully');
      } else {
        return (null, 'Failed to initialize context');
      }
    } finally {
      calloc.free(modelPathC);
    }
  } catch (e) {
    return (null, 'Exception during context initialization: $e');
  }
}

Future<CactusCompletionResult> _completionInIsolate(Map<String, dynamic> params) async {
  final handle = params['handle'] as int;
  final messagesJson = params['messagesJson'] as String;
  final optionsJson = params['optionsJson'] as String;
  final toolsJson = params['toolsJson'] as String?;
  final bufferSize = params['bufferSize'] as int;
  final hasCallback = params['hasCallback'] as bool;
  final SendPort? replyPort = params['replyPort'] as SendPort?;

  final responseBuffer = calloc<Uint8>(bufferSize);
  final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);
  final optionsJsonC = optionsJson.toNativeUtf8(allocator: calloc);
  final toolsJsonC = toolsJson?.toNativeUtf8(allocator: calloc);

  Pointer<NativeFunction<CactusTokenCallbackNative>>? callbackPointer;

  try {
    if (hasCallback && replyPort != null) {
      // Set up token callback to send tokens back through isolate
      _activeTokenCallback = (token) {
        replyPort.send({'type': 'token', 'data': token});
        return true; // Always continue in isolate mode
      };
      
      callbackPointer = Pointer.fromFunction<CactusTokenCallbackNative>(
        _staticTokenCallbackDispatcher
      );
    }

    final result = bindings.cactusComplete(
      Pointer.fromAddress(handle),
      messagesJsonC,
      responseBuffer.cast<Utf8>(),
      bufferSize,
      optionsJsonC,
      toolsJsonC ?? nullptr,
      callbackPointer ?? nullptr,
      nullptr,
    );

    debugPrint('Received completion result code: $result');

    if (result > 0) {
      final responseText = responseBuffer.cast<Utf8>().toDartString().trim();
      
      try {
        final jsonResponse = jsonDecode(responseText) as Map<String, dynamic>;
        print("Parsed JSON response: $jsonResponse");
        final success = jsonResponse['success'] as bool? ?? true;
        final response = jsonResponse['response'] as String? ?? responseText;
        final timeToFirstTokenMs = (jsonResponse['time_to_first_token_ms'] as num?)?.toDouble() ?? 0.0;
        final totalTimeMs = (jsonResponse['total_time_ms'] as num?)?.toDouble() ?? 0.0;
        final tokensPerSecond = (jsonResponse['tokens_per_second'] as num?)?.toDouble() ?? 0.0;
        final prefillTokens = jsonResponse['prefill_tokens'] as int? ?? 0;
        final decodeTokens = jsonResponse['decode_tokens'] as int? ?? 0;
        final totalTokens = jsonResponse['total_tokens'] as int? ?? 0;
        
        // Parse tool calls
        List<ToolCall> toolCalls = [];
        if (jsonResponse['tool_calls'] != null) {
          final toolCallsJson = jsonResponse['tool_calls'] as List<dynamic>;
          toolCalls = toolCallsJson
              .map((toolCallJson) => ToolCall.fromJson(toolCallJson as Map<String, dynamic>))
              .toList();
        }

        return CactusCompletionResult(
          success: success,
          response: response,
          timeToFirstTokenMs: timeToFirstTokenMs,
          totalTimeMs: totalTimeMs,
          tokensPerSecond: tokensPerSecond,
          prefillTokens: prefillTokens,
          decodeTokens: decodeTokens,
          totalTokens: totalTokens,
          toolCalls: toolCalls,
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
          toolCalls: [],
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
        toolCalls: [],
      );
    }
  } finally {
    _activeTokenCallback = null;
    calloc.free(responseBuffer);
    calloc.free(messagesJsonC);
    calloc.free(optionsJsonC);
    if (toolsJsonC != null) {
      calloc.free(toolsJsonC);
    }
  }
}

Future<CactusEmbeddingResult> _generateEmbeddingInIsolate(Map<String, dynamic> params) async {
  final handle = params['handle'] as int;
  final text = params['text'] as String;
  final bufferSize = params['bufferSize'] as int;

  final textC = text.toNativeUtf8(allocator: calloc);
  final embeddingDimPtr = calloc<Size>();
  final embeddingsBuffer = calloc<Float>(bufferSize);

  try {
    debugPrint('Generating embedding for text: ${text.length > 50 ? text.substring(0, 50) + "..." : text}');
    debugPrint('Buffer allocated for $bufferSize float elements');

    // Calculate buffer size in bytes (bufferSize * sizeof(float))
    final bufferSizeInBytes = bufferSize * 4;

    final result = bindings.cactusEmbed(
      Pointer.fromAddress(handle),
      textC,
      embeddingsBuffer,
      bufferSizeInBytes,
      embeddingDimPtr,
    );

    debugPrint('Received embedding result code: $result');

    if (result > 0) {
      final actualEmbeddingDim = embeddingDimPtr.value;
      debugPrint('Actual embedding dimension: $actualEmbeddingDim');
      
      if (actualEmbeddingDim > bufferSize) {
        return CactusEmbeddingResult(
          success: false,
          embeddings: [],
          dimension: 0,
          errorMessage: 'Embedding dimension ($actualEmbeddingDim) exceeds allocated buffer size ($bufferSize)',
        );
      }
      
      final embeddings = <double>[];
      for (int i = 0; i < actualEmbeddingDim; i++) {
        embeddings.add(embeddingsBuffer[i]);
      }
      
      debugPrint('Successfully extracted ${embeddings.length} embedding values');
      
      return CactusEmbeddingResult(
        success: true,
        embeddings: embeddings,
        dimension: actualEmbeddingDim,
      );
    } else {
      return CactusEmbeddingResult(
        success: false,
        embeddings: [],
        dimension: 0,
        errorMessage: 'Embedding generation failed with code $result',
      );
    }
  } catch (e) {
    debugPrint('Exception during embedding generation: $e');
    return CactusEmbeddingResult(
      success: false,
      embeddings: [],
      dimension: 0,
      errorMessage: 'Exception: $e',
    );
  } finally {
    calloc.free(textC);
    calloc.free(embeddingDimPtr);
    calloc.free(embeddingsBuffer);
  }
}

class CactusContext {
  static String _escapeJsonString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  static Map<String, String?> _prepareCompletionJson(
    List<ChatMessage> messages,
    CactusCompletionParams params,
  ) {
    // Prepare messages JSON
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

    // Prepare options JSON
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

    // Prepare tools JSON if tools are provided
    String? toolsJson;
    if (params.tools != null && params.tools!.isNotEmpty) {
      toolsJson = params.tools!.toToolsJson();
    }

    return {
      'messagesJson': messagesJson,
      'optionsJson': optionsJson,
      'toolsJson': toolsJson,
    };
  }

  static Future<(int?, String)> initContext(String modelPath, int contextSize) async {
    // Run the heavy initialization in an isolate using compute
    final isolateParams = {
      'modelPath': modelPath,
      'contextSize': contextSize,
    };

    return await compute(_initContextInIsolate, isolateParams);
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
    final jsonData = _prepareCompletionJson(messages, params);

    return await compute(_completionInIsolate, {
      'handle': handle,
      'messagesJson': jsonData['messagesJson']!,
      'optionsJson': jsonData['optionsJson']!,
      'toolsJson': jsonData['toolsJson'],
      'bufferSize': params.bufferSize,
      'hasCallback': false,
      'replyPort': null,
    });
  }

  static CactusStreamedCompletionResult completionStream(
    int handle,
    List<ChatMessage> messages,
    CactusCompletionParams params,
  ) {
    final jsonData = _prepareCompletionJson(messages, params);

    final controller = StreamController<String>();
    final resultCompleter = Completer<CactusCompletionResult>();
    final replyPort = ReceivePort();

    late StreamSubscription subscription;
    subscription = replyPort.listen((message) {
      if (message is Map) {
        final type = message['type'] as String;
        if (type == 'token') {
          final token = message['data'] as String;
          controller.add(token);
        } else if (type == 'result') {
          final result = message['data'] as CactusCompletionResult;
          resultCompleter.complete(result);
          controller.close();
          subscription.cancel();
          replyPort.close();
        } else if (type == 'error') {
          final error = message['data'];
          if (error is CactusCompletionResult) {
            resultCompleter.complete(error);
          } else {
            resultCompleter.completeError(error.toString());
          }
          controller.addError(error);
          controller.close();
          subscription.cancel();
          replyPort.close();
        }
      }
    });

    Isolate.spawn(_isolateCompletionEntry, {
      'handle': handle,
      'messagesJson': jsonData['messagesJson']!,
      'optionsJson': jsonData['optionsJson']!,
      'toolsJson': jsonData['toolsJson'],
      'bufferSize': params.bufferSize,
      'hasCallback': true,
      'replyPort': replyPort.sendPort,
    });

    return CactusStreamedCompletionResult(
      stream: controller.stream,
      result: resultCompleter.future,
    );
  }

  static Future<CactusEmbeddingResult> generateEmbedding(
    int handle,
    String text, {
    int bufferSize = 2048,
  }) async {
    return await compute(_generateEmbeddingInIsolate, {
      'handle': handle,
      'text': text,
      'bufferSize': bufferSize,
    });
  }

  static Future<void> _isolateCompletionEntry(Map<String, dynamic> params) async {
    final replyPort = params['replyPort'] as SendPort;
    try {
      final result = await _completionInIsolate(params);
      if (result.success) {
        replyPort.send({'type': 'result', 'data': result});
      } else {
        replyPort.send({'type': 'error', 'data': result});
      }
    } catch (e) {
      replyPort.send({'type': 'error', 'data': e.toString()});
    }
  }
}