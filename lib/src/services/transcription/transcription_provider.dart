import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/utils/cactus_id.dart';
import 'package:cactus/src/utils/models/download.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/telemetry.dart';

abstract class BaseTranscriptionProvider {
  bool _isInitialized = false;
  String _lastInitializedModel = "";
  List<VoiceModel> _voiceModels = [];

  // Provider-specific abstract members
  String get providerName;
  String get defaultModel;
  Future<bool> initializeService(String modelPath, {String? additionalModelPath});
  Future<SpeechRecognitionResult?> performRecognition(SpeechRecognitionParams params, String? filePath);
  bool get serviceReady;
  bool get serviceRecording;
  void stopService();
  void disposeService();
  Future<List<DownloadTask>> buildDownloadTasks(VoiceModel model, String modelName);
  String buildModelPath(String appDocPath, String model);

  // Optional additional model path (e.g., speaker model for Vosk)
  String? getAdditionalModelPath(String appDocPath, String model) => null;

  Future<bool> download({
    String? model,
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    final modelName = model ?? defaultModel;

    if (await isModelDownloaded(modelName: modelName)) {
      return true;
    }

    final currentModel = await _getModel(modelName);
    if (currentModel == null) {
      debugPrint("No data found for model: $modelName");
      return false;
    }

    final tasks = await buildDownloadTasks(currentModel, modelName);

    return await DownloadService.downloadAndExtractModels(tasks, downloadProcessCallback);
  }

  Future<bool> init({required String model}) async {
    _isInitialized = false;

    if (!await isModelDownloaded(modelName: model)) {
      await download(model: model);
    }

    try {
      if (!Telemetry.isInitialized) {
        final String projectId = await CactusId.getProjectId();
        final String? deviceId = await Telemetry.fetchDeviceId();
        Telemetry(projectId, deviceId, CactusTelemetry.telemetryToken);
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final modelPath = buildModelPath(appDocDir.path, model);
      final additionalPath = getAdditionalModelPath(appDocDir.path, model);

      _isInitialized = await initializeService(modelPath, additionalModelPath: additionalPath);

      if (Telemetry.isInitialized) {
        final message = _isInitialized ? "" : "Failed to initialize $providerName model: $model";
        Telemetry.instance?.logInit(
          _isInitialized,
          model,
          message,
        );
      }
    } catch (e) {
      debugPrint("Error initializing $providerName: ${e.toString()}");
      if (Telemetry.isInitialized) {
        Telemetry.instance?.logInit(
          false,
          model,
          "Error in initializing $providerName: ${e.toString()}",
        );
      }
    }
    _lastInitializedModel = model;
    return _isInitialized;
  }

  Future<SpeechRecognitionResult?> transcribe({
    SpeechRecognitionParams? params,
    String? filePath,
  }) async {
    final model = params?.model ?? _lastInitializedModel;

    if (!_isInitialized || model != _lastInitializedModel) {
      final initSuccess = await init(model: model);
      if (!initSuccess) {
        debugPrint("Failed to initialize $providerName for model: $model");
        return null;
      }
    }

    final startTime = DateTime.now();
    final transcriptionParams = params ?? SpeechRecognitionParams();
    SpeechRecognitionResult? result;
    String? message;

    if (_isInitialized && serviceReady) {
      try {
        result = await performRecognition(transcriptionParams, filePath);
      } catch (e) {
        result = SpeechRecognitionResult(
          success: false,
          text: "Error during speech recognition: $e",
        );
        message = "Error during speech recognition: $e";
      }
    } else {
      debugPrint("$providerName not initialized.");
      message = "$providerName not initialized";
      return null;
    }

    if (Telemetry.isInitialized) {
      Telemetry.instance?.logTranscription(
        CactusCompletionResult(
          success: result?.success == true,
          response: result?.text ?? '',
          timeToFirstTokenMs: 0,
          totalTimeMs: result?.processingTime ?? 0,
          tokensPerSecond: 0,
          prefillTokens: 0,
          decodeTokens: 0,
          totalTokens: 0,
        ),
        _lastInitializedModel,
        message: message,
        responseTime: DateTime.now().difference(startTime).inMilliseconds.toDouble(),
      );
    }

    return result;
  }

  void stop() {
    stopService();
  }

  bool get isRecording => serviceRecording;

  bool isReady() => _isInitialized && serviceReady;

  Future<List<VoiceModel>> getVoiceModels() async {
    if (_voiceModels.isEmpty) {
      _voiceModels = await Supabase.fetchVoiceModels(provider: providerName);
      for (var model in _voiceModels) {
        model.isDownloaded = await DownloadService.modelExists(model.slug);
      }
    }
    return _voiceModels;
  }

  Future<bool> isModelDownloaded({required String modelName}) async {
    return await DownloadService.modelExists(modelName);
  }

  void dispose() {
    disposeService();
    _isInitialized = false;
  }

  Future<VoiceModel?> _getModel(String slug) async {
    if (_voiceModels.isEmpty) {
      _voiceModels = await getVoiceModels();
    }
    try {
      return _voiceModels.firstWhere((model) => model.slug == slug);
    } catch (e) {
      return null;
    }
  }
}
