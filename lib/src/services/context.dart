import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cactus/models/types.dart';
import 'package:cactus/src/models/binding.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'bindings.dart' as bindings;

// Global callback storage for streaming completions
CactusTokenCallback? _activeTokenCallback;

// Static callback function that can be used with Pointer.fromFunction
@pragma('vm:entry-point')
int _staticTokenCallbackDispatcher(Pointer<Utf8> tokenC, Pointer<Void> userData) {
  try {
    final callback = _activeTokenCallback;
    if (callback != null) {
      final tokenString = tokenC.toDartString();
      final shouldContinue = callback(tokenString);
      return shouldContinue ? 1 : 0; // Return 1 to continue, 0 to stop
    }
    return 1; // Continue if no callback is set
  } catch (e) {
    debugPrint('Token callback error: $e');
    return 0; // Stop on error
  }
}

Future<int?> _initContextInIsolate(Map<String, dynamic> params) async {
  final modelPath = params['modelPath'] as String;
  final contextSize = params['contextSize'] as int;

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

Future<CactusCompletionResult> _completionInIsolate(Map<String, dynamic> params) async {
  final handle = params['handle'] as int;
  final messagesJson = params['messagesJson'] as String;
  final optionsJson = params['optionsJson'] as String;
  final bufferSize = params['bufferSize'] as int;
  final hasCallback = params['hasCallback'] as bool;
  final SendPort? replyPort = params['replyPort'] as SendPort?;

  final responseBuffer = calloc<Uint8>(bufferSize);
  final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);
  final optionsJsonC = optionsJson.toNativeUtf8(allocator: calloc);

  Pointer<NativeFunction<CactusTokenCallbackNative>>? callbackPointer;

  try {
    if (hasCallback && replyPort != null) {
      // Set up token callback to send tokens back through isolate
      _activeTokenCallback = (token) {
        replyPort.send({'type': 'token', 'data': token});
        return true; // Always continue in isolate mode
      };
      
      callbackPointer = Pointer.fromFunction<CactusTokenCallbackNative>(
        _staticTokenCallbackDispatcher,
        1, // Default return value (continue)
      );
    }

    final result = bindings.cactusComplete(
      Pointer.fromAddress(handle),
      messagesJsonC,
      responseBuffer.cast<Utf8>(),
      bufferSize,
      optionsJsonC,
      callbackPointer ?? nullptr,
      nullptr,
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
    _activeTokenCallback = null;
    calloc.free(responseBuffer);
    calloc.free(messagesJsonC);
    calloc.free(optionsJsonC);
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

  static Future<int?> initContext(String modelPath, int contextSize) async {
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
    // Prepare JSON data on main thread
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

    final replyPort = ReceivePort();
    final completer = Completer<CactusCompletionResult>();

    // Listen for tokens and final result
    late StreamSubscription subscription;
    subscription = replyPort.listen((message) {
      if (message is Map) {
        final type = message['type'] as String;
        if (type == 'token') {
          final token = message['data'] as String;
          try {
            params.onToken?.call(token);
          } catch (e) {
            debugPrint('Error in token callback: $e');
          }
        } else if (type == 'result') {
          completer.complete(message['data'] as CactusCompletionResult);
          subscription.cancel();
          replyPort.close();
        } else if (type == 'error') {
          completer.completeError(message['data']);
          subscription.cancel();
          replyPort.close();
        }
      }
    });

    // Start the completion in an isolate
    try {
      final isolate = await Isolate.spawn(_isolateCompletionEntry, {
        'handle': handle,
        'messagesJson': messagesJson,
        'optionsJson': optionsJson,
        'bufferSize': params.bufferSize,
        'hasCallback': params.onToken != null,
        'replyPort': replyPort.sendPort,
      });

      final result = await completer.future;
      isolate.kill();
      return result;
    } catch (e) {
      subscription.cancel();
      replyPort.close();
      rethrow;
    }
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
      replyPort.send({'type': 'result', 'data': result});
    } catch (e) {
      replyPort.send({'type': 'error', 'data': e});
    }
  }
}