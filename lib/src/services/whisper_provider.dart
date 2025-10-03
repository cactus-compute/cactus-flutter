import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/whisper.dart';
import 'package:cactus/src/services/cactus_id.dart';
import 'package:cactus/src/services/download.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:cactus/src/services/transcription_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/telemetry.dart';

class WhisperTranscriptionProvider implements TranscriptionProviderInterface {
  bool _isInitialized = false;
  String _lastDownloadedModelName = "whisper-tiny";
  List<VoiceModel> _voiceModels = [];

  @override
  Future<bool> download({
    String model = "whisper-tiny", 
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    if (await isModelDownloaded(model)) {
      return true;
    }

    final currentModel = await _getModel(model);
    if (currentModel == null) {
      debugPrint("No data found for model: $model");
      return false;
    }

    final tasks = <DownloadTask>[];
    
    if (!await DownloadService.modelExists(currentModel.fileName)) {
      tasks.add(DownloadTask(
        url: currentModel.url,
        filename: "${currentModel.fileName}.bin",
        folder: model,
      ));
    }

    final success = await DownloadService.downloadAndExtractModels(tasks, downloadProcessCallback);
    if (success) {
      _lastDownloadedModelName = model;
    }
    return success;
  }

  @override
  Future<bool> init({String? model}) async {
    _isInitialized = false;
    final modelToUse = model ?? _lastDownloadedModelName;
    
    try {
      if (!Telemetry.isInitialized) {
        final String projectId = await CactusId.getProjectId();
        final String? deviceId = await Telemetry.fetchDeviceId();
        Telemetry(projectId, deviceId, CactusTelemetry.telemetryToken);
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDocDir.path}/models/$modelToUse/${await _getModelFileName(modelToUse)}.bin';

      _isInitialized = await WhisperService.initialize(
        modelPath: modelPath,
      );
      
      if (Telemetry.isInitialized) {
        final message = _isInitialized ? "" : "Failed to initialize Whisper model: $modelToUse";
        Telemetry.instance?.logInit(
          _isInitialized,
          CactusInitParams(model: modelToUse),
          message,
        );
      }

      if (_isInitialized) {
        _lastDownloadedModelName = modelToUse;
        debugPrint('Whisper initialized successfully with native implementation');
      } else {
        debugPrint('Failed to initialize Whisper with native implementation');
      }
    } catch (e) {
      debugPrint("Error initializing Whisper: ${e.toString()}");
      if (Telemetry.isInitialized) {
        Telemetry.instance?.logInit(
          false,
          CactusInitParams(model: modelToUse),
          "Error in initializing Whisper: ${e.toString()}",
        );
      }
    }
    
    return _isInitialized;
  }

  @override
  Future<SpeechRecognitionResult?> transcribe({
    SpeechRecognitionParams? params,
    String? filePath
  }) async {
    final startTime = DateTime.now();
    final transcriptionParams = params ?? SpeechRecognitionParams();
    SpeechRecognitionResult? result;
    String? message;

    if (_isInitialized && WhisperService.isServiceReady) {
      try {
        result = await WhisperService.recognize(
          params: transcriptionParams,
          filePath: filePath,
        );
      } catch (e) {
        result = SpeechRecognitionResult(
          success: false,
          text: "Error during speech recognition: $e",
        );
        message = "Error during speech recognition: $e";
      }
    } else {
      debugPrint("Whisper not initialized.");
      message = "Whisper not initialized";
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
        CactusInitParams(model: _lastDownloadedModelName),
        message: message,
        responseTime: DateTime.now().difference(startTime).inMilliseconds.toDouble()
      );
    }

    return result;
  }

  @override
  void stop() {
    WhisperService.stop();
  }

  @override
  bool get isRecording => WhisperService.isCurrentlyRecording;

  @override
  bool isReady() => _isInitialized && WhisperService.isServiceReady;

  @override
  Future<List<VoiceModel>> getVoiceModels() async {
    if (_voiceModels.isEmpty) {
      _voiceModels = await Supabase.fetchVoiceModels(provider: 'whisper');
      for (var model in _voiceModels) {
        model.isDownloaded = await DownloadService.modelExists(model.fileName);
      }
    }
    return _voiceModels;
  }

  @override
  Future<bool> isModelDownloaded([String? modelName]) async {
    final currentModel = await _getModel(modelName ?? _lastDownloadedModelName);
    if (currentModel == null) {
      debugPrint("No data found for model: $modelName");
      return false;
    }
    return await DownloadService.modelExists(currentModel.fileName);
  }

  @override
  void dispose() {
    WhisperService.dispose();
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

  Future<String> _getModelFileName(String slug) async {
    final model = await _getModel(slug);
    return model?.fileName ?? 'ggml-tiny-q8_0';
  }
}