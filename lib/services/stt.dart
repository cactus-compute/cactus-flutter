import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/context.dart';
import 'package:cactus/src/utils/models/download.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:cactus/src/services/api/telemetry.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CactusSTT {
  int? _handle;
  String? _lastInitializedModel;
  static const String whisperPrompt = '<|startoftranscript|><|en|><|transcribe|><|notimestamps|>';
  CactusInitParams defaultInitParams = CactusInitParams();
  CactusTranscriptionParams defaultTranscriptionParams = CactusTranscriptionParams();
  final List<VoiceModel> _models = [];

  final _handleLock = _AsyncLock();

  Future<void> downloadModel({
    required String model,
    final CactusProgressCallback? downloadProcessCallback,
  }) async {
    if (await _isModelDownloaded(model)) {
      return;
    }

    final voiceModels = await Supabase.fetchVoiceModels();
    final currentModel = voiceModels.firstWhere(
      (m) => m.slug == model,
      orElse: () => throw Exception('Voice model $model not found'),
    );

    final task = DownloadTask(
      url: currentModel.downloadUrl,
      filename: currentModel.fileName,
      folder: currentModel.slug,
    );

    final success = await DownloadService.downloadAndExtractModels([task], downloadProcessCallback);
    if (!success) {
      throw Exception('Failed to download and extract voice model $model from ${currentModel.downloadUrl}');
    }
  }

  Future<void> initializeModel({final CactusInitParams? params}) async {
    if (!Telemetry.isInitialized) {
      await Telemetry.init(CactusTelemetry.telemetryToken);
    }

    final model = params?.model ?? _lastInitializedModel ?? defaultInitParams.model;
    final modelPath = '${(await getApplicationDocumentsDirectory()).path}/models/$model';

    final result = await CactusContext.initContext(modelPath, ((params?.contextSize) ?? defaultInitParams.contextSize)!);
    _handle = result.$1;

    if (_handle == null && !await _isModelDownloaded(model)) {
      debugPrint('Failed to initialize model context with model at $modelPath, trying to download the model first.');
      await downloadModel(model: model);
      return initializeModel(params: params);
    }

    if (Telemetry.isInitialized) {
      Telemetry.instance?.logInit(_handle != null, model, result.$2);
    }

    if (_handle == null) {
      throw Exception('Failed to initialize model context with model at $modelPath');
    }
    _lastInitializedModel = model;
  }

  Future<CactusTranscriptionResult> transcribe({
    required String audioFilePath,
    String prompt = whisperPrompt,
    CactusTranscriptionParams? params,
  }) async {
    return await _handleLock.synchronized(() async {
      final transcriptionParams = params ?? defaultTranscriptionParams;
      final model = _lastInitializedModel ?? defaultInitParams.model;
      final currentHandle = await _getValidatedHandle(model: model);

      if (currentHandle != null) {
        try {
          final result = await CactusContext.transcribe(
            currentHandle,
            audioFilePath,
            prompt,
            params: transcriptionParams,
          );
          _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
          return result;
        } catch (e) {
          debugPrint('Transcription failed: $e');
          _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
          rethrow;
        }
      }

      throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
    });
  }

  Future<CactusStreamedTranscriptionResult> transcribeStream({
    required String audioFilePath,
    String prompt = whisperPrompt,
    CactusTranscriptionParams? params,
  }) async {
    final transcriptionParams = params ?? defaultTranscriptionParams;
    final model = _lastInitializedModel ?? defaultInitParams.model;
    final currentHandle = await _getValidatedHandle(model: model);

    if (currentHandle != null) {
      try {
        final streamedResult = CactusContext.transcribeStream(
          currentHandle,
          audioFilePath,
          prompt,
          params: transcriptionParams,
        );
        streamedResult.result.then((result) {
          _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
        }).catchError((error) {
          _logTranscriptionTelemetry(null, model, success: false, message: error.toString());
        });

        return streamedResult;
      } catch (e) {
        debugPrint('Streaming transcription failed: $e');
        _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
        rethrow;
      }
    }

    throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;

  Future<List<VoiceModel>> getVoiceModels() async {
    if (_models.isEmpty) {
      _models.addAll(await Supabase.fetchVoiceModels());
      for (var model in _models) {
        model.isDownloaded = await _isModelDownloaded(model.slug);
      }
    }
    return _models;
  }

  Future<int?> _getValidatedHandle({required String model}) async {
    if (_handle != null && (model == _lastInitializedModel)) {
      return _handle;
    }

    await initializeModel(params: CactusInitParams(model: model));
    return _handle;
  }

  void _logTranscriptionTelemetry(CactusTranscriptionResult? result, String model, {bool success = true, String? message}) {
    if (Telemetry.isInitialized) {
      Telemetry.instance?.logTranscription(result, model, message: message, success: success);
    }
  }

  Future<bool> _isModelDownloaded(String modelName) async {
    return await DownloadService.modelExists(modelName);
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