import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cactus/models/types.dart';
import 'package:cactus/models/tools.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'bindings.dart' as bindings;

// Dart API DL initialization flag
bool _dartApiInitialized = false;

void _ensureDartApiInitialized() {
  if (!_dartApiInitialized) {
    final initResult = bindings.initializeDartApiDL(NativeApi.initializeApiDLData);
    if (initResult != 0) {
      throw Exception('Failed to initialize Dart API DL');
    }
    _dartApiInitialized = true;
    debugPrint('Dart API DL initialized successfully');
  }
}

Future<(int?, String)> _initContextAsync(String modelPath, int contextSize) async {
  _ensureDartApiInitialized();

  final receivePort = ReceivePort();
  final modelPathC = modelPath.toNativeUtf8(allocator: calloc);

  try {
    debugPrint('Initializing context with model: $modelPath, contextSize: $contextSize (async)');

    bindings.cactusInitAsync(
      modelPathC,
      contextSize,
      receivePort.sendPort.nativePort,
    );

    final result = await receivePort.first;

    if (result is Map) {
      final success = result['success'] as bool;
      if (success) {
        final handle = result['handle'] as int;
        final message = result['message'] as String? ?? 'Context initialized successfully';
        return (handle, message);
      } else {
        final message = result['message'] as String? ?? 'Failed to initialize context';
        return (null, message);
      }
    } else {
      return (null, 'Unexpected result format from async init');
    }
  } catch (e) {
    return (null, 'Exception during context initialization: $e');
  } finally {
    calloc.free(modelPathC);
    receivePort.close();
  }
}

Future<CactusCompletionResult> _completionAsync({
  required int handle,
  required String messagesJson,
  required String optionsJson,
  String? toolsJson,
  required int maxTokens,
  required int quantization,
  bool enableStreaming = false,
  StreamController<String>? tokenController,
}) async {
  _ensureDartApiInitialized();

  final receivePort = ReceivePort();
  final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);
  final optionsJsonC = optionsJson.toNativeUtf8(allocator: calloc);
  final toolsJsonC = toolsJson?.toNativeUtf8(allocator: calloc);

  try {
    debugPrint('Starting async completion (streaming: $enableStreaming)');

    bindings.cactusCompleteAsync(
      Pointer.fromAddress(handle),
      messagesJsonC,
      optionsJsonC,
      toolsJsonC ?? nullptr,
      maxTokens,
      quantization,
      enableStreaming,
      receivePort.sendPort.nativePort,
    );

    CactusCompletionResult? finalResult;

    await for (final message in receivePort) {
      if (message is Map) {
        final type = message['type'] as String?;

        if (type == 'token' && enableStreaming && tokenController != null) {
          final token = message['data'] as String;
          tokenController.add(token);
        } else if (type == 'result' || type == 'complete') {
          final data = message['data'];
          if (data is Map) {
            finalResult = _parseCompletionResult(data);
          }
          break;
        } else if (type == 'error') {
          final errorMsg = message['message'] as String? ?? 'Unknown error';
          finalResult = CactusCompletionResult(
            success: false,
            response: errorMsg,
            timeToFirstTokenMs: 0.0,
            totalTimeMs: 0.0,
            tokensPerSecond: 0.0,
            prefillTokens: 0,
            decodeTokens: 0,
            totalTokens: 0,
            toolCalls: [],
          );
          break;
        }
      }
    }

    return finalResult ?? CactusCompletionResult(
      success: false,
      response: 'No result received from async completion',
      timeToFirstTokenMs: 0.0,
      totalTimeMs: 0.0,
      tokensPerSecond: 0.0,
      prefillTokens: 0,
      decodeTokens: 0,
      totalTokens: 0,
      toolCalls: [],
    );
  } catch (e) {
    debugPrint('Exception during async completion: $e');
    return CactusCompletionResult(
      success: false,
      response: 'Exception: $e',
      timeToFirstTokenMs: 0.0,
      totalTimeMs: 0.0,
      tokensPerSecond: 0.0,
      prefillTokens: 0,
      decodeTokens: 0,
      totalTokens: 0,
      toolCalls: [],
    );
  } finally {
    calloc.free(messagesJsonC);
    calloc.free(optionsJsonC);
    if (toolsJsonC != null) {
      calloc.free(toolsJsonC);
    }
    receivePort.close();
  }
}

CactusCompletionResult _parseCompletionResult(Map<dynamic, dynamic> data) {
  try {
    final success = data['success'] as bool? ?? true;
    final response = data['response'] as String? ?? '';
    final timeToFirstTokenMs = (data['time_to_first_token_ms'] as num?)?.toDouble() ?? 0.0;
    final totalTimeMs = (data['total_time_ms'] as num?)?.toDouble() ?? 0.0;
    final tokensPerSecond = (data['tokens_per_second'] as num?)?.toDouble() ?? 0.0;
    final prefillTokens = data['prefill_tokens'] as int? ?? 0;
    final decodeTokens = data['decode_tokens'] as int? ?? 0;
    final totalTokens = data['total_tokens'] as int? ?? 0;

    // Parse tool calls
    List<ToolCall> toolCalls = [];
    if (data['tool_calls'] != null) {
      final toolCallsJson = data['tool_calls'] as List<dynamic>;
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
    debugPrint('Unable to parse completion result: $e');
    return CactusCompletionResult(
      success: false,
      response: 'Error parsing result: $e',
      timeToFirstTokenMs: 0.0,
      totalTimeMs: 0.0,
      tokensPerSecond: 0.0,
      prefillTokens: 0,
      decodeTokens: 0,
      totalTokens: 0,
      toolCalls: [],
    );
  }
}

Future<CactusEmbeddingResult> _generateEmbeddingAsync({
  required int handle,
  required String text,
  required int quantization,
}) async {
  _ensureDartApiInitialized();

  final receivePort = ReceivePort();
  final textC = text.toNativeUtf8(allocator: calloc);

  try {
    debugPrint('Generating embedding for text: ${text.length > 50 ? '${text.substring(0, 50)}...' : text} (async)');

    bindings.cactusEmbedAsync(
      Pointer.fromAddress(handle),
      textC,
      quantization,
      receivePort.sendPort.nativePort,
    );

    final result = await receivePort.first;

    if (result is Map) {
      final success = result['success'] as bool;
      if (success) {
        final embeddingsData = result['embeddings'] as List<dynamic>;
        final embeddings = embeddingsData.map((e) => (e as num).toDouble()).toList();
        final dimension = result['dimension'] as int;

        debugPrint('Successfully received ${embeddings.length} embedding values');

        return CactusEmbeddingResult(
          success: true,
          embeddings: embeddings,
          dimension: dimension,
        );
      } else {
        final errorMsg = result['message'] as String? ?? 'Embedding generation failed';
        return CactusEmbeddingResult(
          success: false,
          embeddings: [],
          dimension: 0,
          errorMessage: errorMsg,
        );
      }
    } else {
      return CactusEmbeddingResult(
        success: false,
        embeddings: [],
        dimension: 0,
        errorMessage: 'Unexpected result format from async embedding',
      );
    }
  } catch (e) {
    debugPrint('Exception during async embedding generation: $e');
    return CactusEmbeddingResult(
      success: false,
      embeddings: [],
      dimension: 0,
      errorMessage: 'Exception: $e',
    );
  } finally {
    calloc.free(textC);
    receivePort.close();
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
    params.temperature != null ? optionsJsonBuffer.write('"temperature":${params.temperature},') : null;
    params.topK != null ? optionsJsonBuffer.write('"top_k":${params.topK},') : null;
    params.topP != null ? optionsJsonBuffer.write('"top_p":${params.topP},') : null;
    optionsJsonBuffer.write('"max_tokens":${params.maxTokens}');
    if (params.stopSequences.isNotEmpty) {
      optionsJsonBuffer.write(',"stop_sequences":[');
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
    return await _initContextAsync(modelPath, contextSize);
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

    return await _completionAsync(
      handle: handle,
      messagesJson: jsonData['messagesJson']!,
      optionsJson: jsonData['optionsJson']!,
      toolsJson: jsonData['toolsJson'],
      maxTokens: params.maxTokens,
      quantization: params.quantization,
      enableStreaming: false,
    );
  }

  static CactusStreamedCompletionResult completionStream(
    int handle,
    List<ChatMessage> messages,
    CactusCompletionParams params,
  ) {
    final jsonData = _prepareCompletionJson(messages, params);

    final controller = StreamController<String>();
    final resultCompleter = Completer<CactusCompletionResult>();

    // Run async completion with streaming in the background
    _completionAsync(
      handle: handle,
      messagesJson: jsonData['messagesJson']!,
      optionsJson: jsonData['optionsJson']!,
      toolsJson: jsonData['toolsJson'],
      maxTokens: params.maxTokens,
      quantization: params.quantization,
      enableStreaming: true,
      tokenController: controller,
    ).then((result) {
      resultCompleter.complete(result);
      controller.close();
    }).catchError((error) {
      resultCompleter.completeError(error);
      controller.addError(error);
      controller.close();
    });

    return CactusStreamedCompletionResult(
      stream: controller.stream,
      result: resultCompleter.future,
    );
  }

  static Future<CactusEmbeddingResult> generateEmbedding(int handle, String text, int quantization) async {
    return await _generateEmbeddingAsync(
      handle: handle,
      text: text,
      quantization: quantization,
    );
  }
}
