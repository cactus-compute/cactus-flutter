import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cactus/models/tools.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/cactus_id.dart';
import 'package:cactus/src/services/context.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../src/services/telemetry.dart';

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
    final actualFilename = currentModel.downloadUrl.split('?').first.split('/').last;
    final success = await _downloadAndExtractModel(currentModel.downloadUrl, actualFilename, currentModel.slug, downloadProcessCallback);
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
    final modelPath = '${appDocDir.path}/$model';

    _handle = await CactusContext.initContext(modelPath, ((params?.contextSize) ?? defaultInitParams.contextSize)!);
    _lastDownloadedModel = model;
    if(Telemetry.isInitialized) {
      params?.model = model;
      Telemetry.instance?.logInit(_handle != null, params?? defaultInitParams);
    }
    if(_handle == null) {
      throw Exception('Failed to initialize model context with model at $modelPath');
    }
  }

  Future<CactusCompletionResult> generateCompletion({
    required List<ChatMessage> messages,
    CactusCompletionParams? params
  }) async {
    if (_lastDownloadedModel == null || !await _isModelDownloaded(_lastDownloadedModel!)) {
      throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
    }
    final currentHandle = _getValidatedHandle();
    final initParams = CactusInitParams(model: _lastDownloadedModel!);
    
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
    );
    
    try {
      final result = await CactusContext.completion(currentHandle, messages, paramsWithTools);
      _logCompletionTelemetry(result, initParams);      
      return result;
    } catch (e) {
      _logCompletionTelemetry(null, initParams, success: false, message: e.toString());
      rethrow;
    }
  }

  Future<CactusStreamedCompletionResult> generateCompletionStream({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
    List<CactusTool>? tools,
  }) async {
    if (_lastDownloadedModel == null || !await _isModelDownloaded(_lastDownloadedModel!)) {
      throw Exception('Model $_lastDownloadedModel is not downloaded. Please download it before generating completions.');
    }
    final currentHandle = _getValidatedHandle();
    final initParams = CactusInitParams(model: _lastDownloadedModel!);
    
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
    );
    
    try {
      final streamedResult = CactusContext.completionStream(currentHandle, messages, paramsWithTools);      
      streamedResult.result.then((result) {
        _logCompletionTelemetry(result, initParams, success: result.success);
      }).catchError((error) {
        _logCompletionTelemetry(null, initParams, success: false, message: error.toString());
      });
      
      return streamedResult;
    } catch (e) {
      _logCompletionTelemetry(null, initParams, success: false, message: e.toString());
      rethrow;
    }
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

  Future<bool> _downloadAndExtractModel(String url, String filename, String folder, CactusProgressCallback? downloadProcessCallback) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelFolderPath = '${appDocDir.path}/$folder';
    final modelFolder = Directory(modelFolderPath);
    
    if (await modelFolder.exists()) {
      final files = await modelFolder.list().toList();
      if (files.isNotEmpty) {
        debugPrint('Model folder already exists at $modelFolderPath with ${files.length} files');
        return true;
      }
    }
    
    final zipFilePath = '${appDocDir.path}/$filename';
    final client = HttpClient();
    
    try {
      debugPrint('Downloading ZIP file from $url');
      downloadProcessCallback?.call(null, 'Starting download...', false);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        downloadProcessCallback?.call(null, 'Failed to download ZIP file: ${response.statusCode}', true);
        throw Exception('Failed to download ZIP file: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      downloadProcessCallback?.call(null, 'Download started...', false);
      final zipFile = File(zipFilePath);
      final sink = zipFile.openWrite();
      
      int totalBytes = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        totalBytes += chunk.length;
        if (contentLength > 0) {
          final progress = totalBytes / contentLength;
          downloadProcessCallback?.call(progress, 'Downloaded ${totalBytes ~/ (1024 * 1024)} MB...', false);
        } else if (totalBytes % (10 * 1024 * 1024) == 0) {
          downloadProcessCallback?.call(null, 'Downloaded ${totalBytes ~/ (1024 * 1024)} MB...', false);
        }
      }
      await sink.close();
      downloadProcessCallback?.call(1.0, 'Download completed, extracting...', false);
      await modelFolder.create(recursive: true);
      downloadProcessCallback?.call(null, 'Extracting files...', false);
      final inputStream = InputFileStream(zipFilePath);
      
      try {
        final archive = ZipDecoder().decodeStream(inputStream);
        final symbolicLinks = [];
        
        for (final file in archive) {
          if (file.isSymbolicLink) {
            symbolicLinks.add(file);
            continue;
          }
          
          if (file.isFile) {
            final extractedFilePath = '$modelFolderPath/${file.name}';
            
            final extractedFileParent = File(extractedFilePath).parent;
            await extractedFileParent.create(recursive: true);            
            final outputStream = OutputFileStream(extractedFilePath);
            file.writeContent(outputStream);
            outputStream.closeSync();
          } else {
            final dirPath = '$modelFolderPath/${file.name}';
            await Directory(dirPath).create(recursive: true);
          }
        }
        
        for (final file in symbolicLinks) {
          final linkPath = '$modelFolderPath/${file.name}';
          final link = Link(linkPath);
          await link.create(file.symbolicLink!, recursive: true);
        }
      } finally {
        inputStream.close();
      }
      
      await zipFile.delete();
      downloadProcessCallback?.call(1.0, 'Extraction completed successfully', false);
      debugPrint('ZIP extraction completed successfully to $modelFolderPath');
      return true;
    } catch (e) {
      downloadProcessCallback?.call(null, 'Download and extraction failed: $e', true);
      debugPrint('Download and extraction failed: $e');
      try {
        final zipFile = File(zipFilePath);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
        if (await modelFolder.exists()) {
          final files = await modelFolder.list().toList();
          if (files.length < 5) {
            await modelFolder.delete(recursive: true);
          }
        }
      } catch (cleanupError) {
        debugPrint('Error during cleanup: $cleanupError');
      }
      return false;
    } finally {
      client.close();
    }
  }

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
        model.isDownloaded = await _modelExists(model.slug);
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
    return await _modelExists(currentModel.slug);
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

  Future<bool> _modelExists(String slug) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelFolderPath = '${appDocDir.path}/$slug';
    final modelFolder = Directory(modelFolderPath);
    if (await modelFolder.exists()) {
      final files = await modelFolder.list().toList();
      return files.isNotEmpty;
    }
    return false;
  }
}