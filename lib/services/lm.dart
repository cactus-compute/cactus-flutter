import 'dart:async';

import 'package:cactus/models/tools.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/cactus_id.dart';
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
      final String projectId = await CactusId.getProjectId();
      final String? deviceId = await Telemetry.fetchDeviceId();
      Telemetry(projectId, deviceId, CactusTelemetry.telemetryToken);
    }

    final model = params?.model?? defaultInitParams.model;
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/models/$model';

    final result = await CactusContext.initContext(modelPath, ((params?.contextSize) ?? defaultInitParams.contextSize)!);
    _handle = result.$1; 
    _lastDownloadedModel = model;
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
    final initParams = CactusInitParams(model: _lastDownloadedModel ?? defaultInitParams.model);
    
    // Create params with tools if provided
    final completionParams = params ?? defaultCompletionParams;
    final paramsWithTools = CactusCompletionParams(
      temperature: completionParams.temperature,
      topK: completionParams.topK,
      topP: completionParams.topP,
      maxTokens: completionParams.maxTokens,
      stopSequences: completionParams.stopSequences,
      bufferSize: completionParams.bufferSize,
      tools: completionParams.tools,
      completionMode: completionParams.completionMode,
    );

    debugPrint('Completion mode: ${paramsWithTools.completionMode}');
    
    if (_handle != null && _lastDownloadedModel != null && await _isModelDownloaded(_lastDownloadedModel!)) {
      try {
        final result = await CactusContext.completion(_handle!, messages, paramsWithTools);
        _logCompletionTelemetry(result, initParams);      
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
        _logCompletionTelemetry(result, initParams, success: result.success);
        return result;
      } catch (e) {
        _logCompletionTelemetry(null, initParams, success: false, message: 'Cloud completion failed: $e');
        throw Exception('Cloud completion failed: $e');
      }
    }
    
    throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
  }

  Future<CactusStreamedCompletionResult> generateCompletionStream({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
    List<CactusTool>? tools,
    String? cactusToken,
  }) async {
    final initParams = CactusInitParams(model: _lastDownloadedModel ?? defaultInitParams.model);

    // Create params with tools if provided
    final completionParams = params ?? defaultCompletionParams;
    final paramsWithTools = CactusCompletionParams(
      temperature: completionParams.temperature,
      topK: completionParams.topK,
      topP: completionParams.topP,
      maxTokens: completionParams.maxTokens,
      stopSequences: completionParams.stopSequences,
      bufferSize: completionParams.bufferSize,
      tools: tools ?? completionParams.tools,
      completionMode: completionParams.completionMode,
    );

    debugPrint('Completion mode: ${paramsWithTools.completionMode}');

    if (_handle != null && _lastDownloadedModel != null && await _isModelDownloaded(_lastDownloadedModel!)) {
      try {
        final streamedResult = CactusContext.completionStream(_getValidatedHandle(), messages, paramsWithTools);
        streamedResult.result.then((result) {
          _logCompletionTelemetry(result, initParams, success: result.success);
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
          _logCompletionTelemetry(result, initParams, success: result.success);
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

  Future<CactusEmbeddingResult> generateEmbedding({
    required String text,
    int bufferSize = 2048,
  }) async {
    if (_lastDownloadedModel == null || !await _isModelDownloaded(_lastDownloadedModel!)) {
      throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
    }
    final currentHandle = _getValidatedHandle();
    final initParams = CactusInitParams(model: _lastDownloadedModel!);
    try {
      final result = await CactusContext.generateEmbedding(currentHandle, text, bufferSize: bufferSize);
      _logEmbeddingTelemetry(result, initParams);
      return result;
    } catch (e) {
      _logEmbeddingTelemetry(null, initParams, success: false, message: e.toString());
      rethrow;
    }
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;

  int _getValidatedHandle() {
    final currentHandle = _handle;
    if (currentHandle == null) {
      _logCompletionTelemetry(null, CactusInitParams(model: _lastDownloadedModel!), success: false, message: "Context not initialized");
      throw CactusException('Context not initialized');
    }
    return currentHandle;
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