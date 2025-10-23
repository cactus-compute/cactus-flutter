import 'dart:async';

import 'package:cactus/models/tools.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/services/tool_filter.dart';
import 'package:cactus/src/services/context.dart';
import 'package:cactus/src/services/download.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:cactus/src/services/openrouter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cactus/src/services/telemetry.dart';

class CactusLM {
  int? _handle;
  String? _lastDownloadedModel;
  CactusInitParams defaultInitParams = CactusInitParams(model: "qwen3-0.6", contextSize: 2048);
  CactusCompletionParams defaultCompletionParams = CactusCompletionParams();
  List<CactusModel> _models = [];

  bool enableToolFiltering;
  ToolFilterConfig? toolFilterConfig;  
  ToolFilterService? _toolFilterService;
  final _handleLock = _AsyncLock();
  
  CactusLM({
    this.enableToolFiltering = true,
    this.toolFilterConfig,
  });

  Future<void> downloadModel({
    String model = "qwen3-0.6",
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    if (await _isModelDownloaded(model)) {
      _lastDownloadedModel = model;
      return;
    }
    
    final currentModel = await _getModel(model);
    if (currentModel == null) {
      throw Exception('Failed to get model $model');
    }
    
    final tasks = <DownloadTask>[];
    
    if (!await DownloadService.modelExists(currentModel.slug)) {
      final actualFilename = currentModel.downloadUrl.split('?').first.split('/').last;
      tasks.add(DownloadTask(
        url: currentModel.downloadUrl,
        filename: actualFilename,
        folder: currentModel.slug,
      ));
    }

    final success = await DownloadService.downloadAndExtractModels(tasks, downloadProcessCallback);
    if (success) {
      _lastDownloadedModel = model;
    }
    if (!success) {
      throw Exception('Failed to download and extract model $model from ${currentModel.downloadUrl}');
    }
  }

  Future<void> initializeModel({CactusInitParams? params}) async {
    if (!Telemetry.isInitialized) {
      await Telemetry.init(CactusTelemetry.telemetryToken);
    }

    final model = params?.model?? defaultInitParams.model;
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/models/$model';

    final result = await CactusContext.initContext(modelPath, ((params?.contextSize) ?? defaultInitParams.contextSize)!);
    _handle = result.$1; 
    _lastDownloadedModel = model;
    if(_handle == null && !await _isModelDownloaded(model)) {
      debugPrint('Failed to initialize model context with model at $modelPath, trying to download the model first.');
      await downloadModel(model: model);
      await initializeModel(params: params);
    }
    if(Telemetry.isInitialized) {
      params?.model = model;
      Telemetry.instance?.logInit(_handle != null, params?? defaultInitParams, result.$2);
    }
    if(_handle == null) {
      throw Exception('Failed to initialize model context with model at $modelPath');
    }
  }

  Future<CactusCompletionResult> generateCompletion({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
    String? cactusToken,
  }) async {
    return await _handleLock.synchronized(() async {
      final completionParams = params ?? defaultCompletionParams;
      final model = completionParams.model ?? _lastDownloadedModel ?? defaultInitParams.model;
      final initParams = CactusInitParams(model: model);
      final modelMetadata = await _getModel(model);
      
      List<CactusTool>? toolsToUse = completionParams.tools;
      if (enableToolFiltering && completionParams.tools != null && completionParams.tools!.isNotEmpty) {
        toolsToUse = await _filterTools(messages, completionParams.tools!);
      }
      
      // Create params with filtered tools
      final paramsWithTools = CactusCompletionParams(
        model: completionParams.model,
        temperature: completionParams.temperature,
        topK: completionParams.topK,
        topP: completionParams.topP,
        maxTokens: completionParams.maxTokens,
        stopSequences: completionParams.stopSequences,
        tools: toolsToUse,
        completionMode: completionParams.completionMode,
        quantization: modelMetadata?.quantization ?? 8,
      );

      debugPrint('Completion mode: ${paramsWithTools.completionMode}');

      int? currentHandle = await _getValidatedHandle(model: model);

      if (currentHandle != null) {
        try {
          final result = await CactusContext.completion(currentHandle, messages, paramsWithTools);
          _logCompletionTelemetry(result, initParams, success: result.success, message: result.success ? null : result.response);
          return result;
        } catch (e) {
          debugPrint('Local completion failed: $e');
          if (paramsWithTools.completionMode == CompletionMode.local || (paramsWithTools.completionMode == CompletionMode.hybrid && cactusToken == null)) {
            _logCompletionTelemetry(null, initParams, success: false, message: e.toString());
            rethrow;
          }
          debugPrint('Falling back to cloud completion');
        }
      }
      
      if (paramsWithTools.completionMode == CompletionMode.hybrid && cactusToken != null) {
        try {
          final openRouterService = OpenRouterService(apiKey: cactusToken);
          final result = await openRouterService.generateCompletion(
            messages: messages,
            params: params,
          );
          openRouterService.dispose();
          _logCompletionTelemetry(result, initParams, success: result.success, message: result.success ? null : result.response);
          return result;
        } catch (e) {
          _logCompletionTelemetry(null, initParams, success: false, message: 'Cloud completion failed: $e');
          throw Exception('Cloud completion failed: $e');
        }
      }
      
      throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
    });
  }

  Future<CactusStreamedCompletionResult> generateCompletionStream({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
    List<CactusTool>? tools,
    String? cactusToken,
  }) async {
    final completionParams = params ?? defaultCompletionParams;
    final model = completionParams.model ?? _lastDownloadedModel ?? defaultInitParams.model;
    final initParams = CactusInitParams(model: model);
    final modelMetadata = await _getModel(model);

    List<CactusTool>? toolsToUse = tools ?? completionParams.tools;
    if (enableToolFiltering && toolsToUse != null && toolsToUse.isNotEmpty) {
      toolsToUse = await _filterTools(messages, toolsToUse);
    }

    // Create params with filtered tools
    final paramsWithTools = CactusCompletionParams(
      model: completionParams.model,
      temperature: completionParams.temperature,
      topK: completionParams.topK,
      topP: completionParams.topP,
      maxTokens: completionParams.maxTokens,
      stopSequences: completionParams.stopSequences,
      tools: toolsToUse,
      completionMode: completionParams.completionMode,
      quantization: modelMetadata?.quantization ?? 8,
    );

    debugPrint('Completion mode: ${paramsWithTools.completionMode}');

    int? currentHandle = await _getValidatedHandle(model: model);

    if (currentHandle != null) {
      try {
        final streamedResult = CactusContext.completionStream(currentHandle, messages, paramsWithTools);
        streamedResult.result.then((result) {
          _logCompletionTelemetry(result, initParams, success: result.success, message: result.success ? null : result.response);
        }).catchError((error) {
          _logCompletionTelemetry(null, initParams, success: false, message: error.toString());
        });

        return streamedResult;
      } catch (e) {
        debugPrint('Local streaming completion failed: $e');
        if (paramsWithTools.completionMode == CompletionMode.local || (paramsWithTools.completionMode == CompletionMode.hybrid && cactusToken == null)) {
          _logCompletionTelemetry(null, initParams, success: false, message: e.toString());
          rethrow;
        }
        debugPrint('Falling back to cloud streaming completion');
      }
    }

    if (paramsWithTools.completionMode == CompletionMode.hybrid && cactusToken != null) {
      try {
        final openRouterService = OpenRouterService(apiKey: cactusToken);
        final streamedResult = await openRouterService.generateCompletionStream(
          messages: messages,
          params: params,
        );
        streamedResult.result.whenComplete(() => openRouterService.dispose());
        streamedResult.result.then((result) {
          _logCompletionTelemetry(result, initParams, success: result.success, message: result.success ? null : result.response);
        }).catchError((error) {
          _logCompletionTelemetry(null, initParams, success: false, message: 'Cloud streaming completion failed: $error');
        });
        return streamedResult;
      } catch (e) {
        _logCompletionTelemetry(null, initParams, success: false, message: 'Cloud streaming completion failed: $e');
        throw Exception('Cloud streaming completion failed: $e');
      }
    }

    throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
  }

  Future<CactusEmbeddingResult> generateEmbedding({required String text, String? modelName}) async {
    return await _handleLock.synchronized(() async {
      if (_lastDownloadedModel == null || !await _isModelDownloaded(_lastDownloadedModel!)) {
        throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
      }
      final currentHandle = await _getValidatedHandle();
      final model = modelName ?? _lastDownloadedModel ?? defaultInitParams.model;
      final initParams = CactusInitParams(model: model);
      final modelMetadata = await _getModel(model);

      try {
        if(currentHandle != null) {
          final result = await CactusContext.generateEmbedding(currentHandle, text, modelMetadata?.quantization ?? 8);
          _logEmbeddingTelemetry(result, initParams, success: result.success, message: result.errorMessage);
          return result;
        } else {
          throw Exception('Context not initialized');
        }
      } catch (e) {
        _logEmbeddingTelemetry(null, initParams, success: false, message: e.toString());
        rethrow;
      }
    });
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;

  Future<int?> _getValidatedHandle({String? model}) async {
    if (_handle != null && (model == null || model == _lastDownloadedModel)) {
      return _handle;
    }
    
    final targetModel = model ?? _lastDownloadedModel ?? defaultInitParams.model;
    await initializeModel(params: CactusInitParams(model: targetModel));
    return _handle;
  }

  void _logCompletionTelemetry(CactusCompletionResult? result, CactusInitParams initParams, {bool success = true, String? message}) {
    if (Telemetry.isInitialized) {
      Telemetry.instance?.logCompletion(result, initParams, message: message, success: success);
    }
  }

  void _logEmbeddingTelemetry(CactusEmbeddingResult? result, CactusInitParams initParams, {bool success = true, String? message}) {
    if (Telemetry.isInitialized) {
      Telemetry.instance?.logEmbedding(result, initParams, message: message, success: success);
    }
  }

  Future<List<CactusTool>> _filterTools(List<ChatMessage> messages, List<CactusTool> tools) async {
    _toolFilterService ??= ToolFilterService(
      config: toolFilterConfig ?? ToolFilterConfig.simple(),
      lm: this
    );
    
    final userQuery = messages.lastWhere(
      (msg) => msg.role == 'user',
      orElse: () => messages.last,
    ).content;
    
    final filteredTools = await _toolFilterService!.filterTools(userQuery, tools);
    
    if (filteredTools.length != tools.length) {
      debugPrint('Tool filtering: ${tools.length} -> ${filteredTools.length} tools');
      debugPrint('Filtered tools: ${filteredTools.map((t) => t.name).join(', ')}');
    }
    
    return filteredTools;
  }

  Future<List<CactusModel>> getModels() async {
    if (_models.isEmpty) {
      _models = await Supabase.fetchModels();
      for (var model in _models) {
        model.isDownloaded = await _isModelDownloaded(model.slug);
      }
    }
    return _models;
  }

  Future<bool> _isModelDownloaded([String? modelName]) async {
    final currentModel = await _getModel(modelName ?? _lastDownloadedModel!);
    if (currentModel == null) {
      print("No data found for model: $_lastDownloadedModel");
      return false;
    }
    return await DownloadService.modelExists(currentModel.slug);
  }

  Future<CactusModel?> _getModel(String slug) async {
    if (_models.isEmpty) {
      _models = await getModels();
    }
    try {
      return _models.firstWhere((model) => model.slug == slug);
    } catch (e) {
      return null;
    }
  }
}

class _AsyncLock {
  Completer<void>? _completer;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_completer != null) {
      await _completer!.future;
    }

    _completer = Completer<void>();

    try {
      return await fn();
    } finally {
      final completer = _completer;
      _completer = null;
      completer?.complete();
    }
  }
}