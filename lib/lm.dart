import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import './types.dart';
import './context.dart';
import './telemetry.dart';
import './remote.dart';
import './chat.dart';

class CactusLM {
  CactusContext? _context;
  CactusInitParams? _initParams;
  final ConversationHistoryManager _historyManager = ConversationHistoryManager();
  String? _lastDownloadedFilename;

  CactusLM._();

  factory CactusLM() => CactusLM._();

  Future<bool> download({
    required String modelUrl,
    String? modelFilename,
    CactusProgressCallback? onProgress,
  }) async {
    try {
      final actualFilename = modelFilename ?? modelUrl.split('/').last;
      if (actualFilename.isEmpty) {
        throw ArgumentError('Cannot determine filename from URL and no filename provided');
      }

      final success = await CactusContext.downloadModels(
        modelUrl: modelUrl,
        modelFilename: modelFilename,
        onProgress: onProgress,
      );
      if (success) {
        _lastDownloadedFilename = actualFilename;
      }
      return success;
    } catch (e) {
      if (onProgress != null) {
        onProgress(null, "Download failed: ${e.toString()}", true);
      }
      return false;
    }
  }

  Future<bool> init({
    String? modelFilename,
    String? chatTemplate,
    int contextSize = 2048,
    int gpuLayers = 0,
    int threads = 4,
    bool generateEmbeddings = false,
    CactusProgressCallback? onProgress,
    String? cactusToken,
  }) async {
    if (cactusToken != null) {
      setCactusToken(cactusToken);
    }

    final filename = modelFilename ?? _lastDownloadedFilename;
    if (filename == null) {
      throw ArgumentError('No model filename provided and no model was previously downloaded');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/$filename';
    
    final file = File(modelPath);
    if (!await file.exists()) {
      throw ArgumentError('Model file does not exist at path: $modelPath');
    }

    final initParams = CactusInitParams(
      modelPath: modelPath,
      chatTemplate: chatTemplate,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      threads: threads,
      generateEmbeddings: generateEmbeddings,
      onInitProgress: onProgress,
    );

    _initParams = initParams;
    
    try {
      if (onProgress != null) {
        onProgress(null, "Initializing...", false);
      }
      _context = await CactusContext.init(initParams);
      return true;
    } catch (e) {
      CactusTelemetry.error(e, initParams);
      if (onProgress != null) {
        onProgress(null, "Initialization failed: ${e.toString()}", true);
      }
      return false;
    }
  }

  bool isLoaded() => _context != null;

  Future<CactusCompletionResult> completion(
    List<ChatMessage> messages, {
    int maxTokens = 256,
    double? temperature,
    int? topK,
    double? topP,
    List<String>? stopSequences,
    CactusTokenCallback? onToken,
  }) async {
    if (_context == null) throw CactusException('CactusLM not initialized');

    final processed = _historyManager.processNewMessages(messages);
    if (processed.requiresReset) {
      _context!.rewind();
      _historyManager.reset();
    }
    
    final result = await _context!.completion(
      CactusCompletionParams(
        messages: processed.newMessages,
        maxPredictedTokens: maxTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        stopSequences: stopSequences,
        onNewToken: onToken,
      ),
    );
    
    _historyManager.update(processed.newMessages, ChatMessage(role: 'assistant', content: result.text));

    return result;
  }

  Future<List<double>> embedding(String text, {String mode = "local"}) async {
    final startTime = DateTime.now();
    
    List<double>? result;
    Exception? lastError;

    if (mode == "remote") {
      result = await _handleRemoteEmbedding(text);
    } else if (mode == "local") {
      result = await _handleLocalEmbedding(text);
    } else if (mode == "localfirst") {
      try {
        result = await _handleLocalEmbedding(text);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        try {
          result = await _handleRemoteEmbedding(text);
        } catch (remoteError) {
          throw lastError;
        }
      }
    } else if (mode == "remotefirst") {
      try {
        result = await _handleRemoteEmbedding(text);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        try {
          result = await _handleLocalEmbedding(text);
        } catch (localError) {
          throw lastError;
        }
      }
    } else {
      throw ArgumentError('Invalid mode: $mode. Must be "local", "remote", "localfirst", or "remotefirst"');
    }
    
    if (_initParams != null) {
      final endTime = DateTime.now();
      final totalTime = endTime.difference(startTime).inMilliseconds;
      
      CactusTelemetry.track({
        'event': 'embedding',
        'embedding_time': totalTime,
        'mode': mode,
      }, _initParams!);
    }
    
    return result;
  }

  void dispose() {
    _context?.release();
    _context = null;
  }

  Future<List<double>> _handleLocalEmbedding(String text) async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return await _context!.embedding(text);
  }

  Future<List<double>> _handleRemoteEmbedding(String text) async {
    return await getVertexAIEmbedding(text);
  }

  Future<List<int>> tokenize(String text) async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return await _context!.tokenize(text);
  }

  Future<String> detokenize(List<int> tokens) async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return await _context!.detokenize(tokens);
  }

  Future<void> applyLoraAdapters(List<LoraAdapterInfo> adapters) async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    await _context!.applyLoraAdapters(adapters);
  }

  Future<void> removeLoraAdapters() async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    await _context!.removeLoraAdapters();
  }

  Future<List<LoraAdapterInfo>> getLoadedLoraAdapters() async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    return await _context!.getLoadedLoraAdapters();
  }

  Future<void> rewind() async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    await _context!.rewind();
  }

  Future<void> stopCompletion() async {
    if (_context == null) throw CactusException('CactusLM not initialized');
    await _context!.stopCompletion();
  }
} 