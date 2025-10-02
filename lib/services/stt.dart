import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/cactus_id.dart';
import 'package:cactus/src/services/download.dart';
import 'package:cactus/src/services/speech_recognition.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../src/services/telemetry.dart';

class CactusSTT {
  bool _isInitialized = false;
  String _lastDownloadedModelName = "vosk-en-us";
  List<VoiceModel> _voiceModels = [];
  
  // Speaker model is universal, no need to change it for different languages
  static const String _spkModelFolder = "vosk-model-spk-0.4";
  static const String _spkModelUrl = "https://alphacephei.com/vosk/models/vosk-model-spk-0.4.zip";

  Future<bool> download({
    String model = "vosk-en-us",
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    if (await isModelDownloaded(model) && await DownloadService.modelExists(_spkModelFolder)) {
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
        filename: "${currentModel.fileName}.zip",
        folder: model,
      ));
    }
    
    if (!await DownloadService.modelExists(_spkModelFolder)) {
      tasks.add(DownloadTask(
        url: _spkModelUrl,
        filename: "$_spkModelFolder.zip",
        folder: _spkModelFolder,
      ));
    }

    final success = await DownloadService.downloadAndExtractModels(tasks, downloadProcessCallback);
    if (success) {
      _lastDownloadedModelName = model;
    }
    return success;
  }

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
      final modelPath = '${appDocDir.path}/models/$modelToUse';
      final spkModelPath = '${appDocDir.path}/models/$_spkModelFolder';

      _isInitialized = await SpeechRecognitionService.initialize(modelPath, spkModelPath);
      
      if (Telemetry.isInitialized) {
        final message = _isInitialized ? "" : "Failed to initialize model: $modelToUse";
        Telemetry.instance?.logInit(
          _isInitialized,
          CactusInitParams(model: modelToUse),
          message,
        );
      }
    } catch (e) {
      debugPrint("Error initializing STT: ${e.toString()}");
      if (Telemetry.isInitialized) {
        Telemetry.instance?.logInit(
          false,
          CactusInitParams(model: modelToUse),
          "Error in initializing STT: ${e.toString()}",
        );
      }
    }
    
    return _isInitialized;
  }

  Future<SpeechRecognitionResult?> transcribe({
    SpeechRecognitionParams? params,
    String? filePath
  }) async {
    final startTime = DateTime.now();
    final transcriptionParams = params ?? SpeechRecognitionParams();
    SpeechRecognitionResult? result;
    String? message;

    if (_isInitialized) {
        result = await SpeechRecognitionService.recognize(
          params: transcriptionParams,
          filePath: filePath
      );
    } else {
      debugPrint("Local STT not initialized.");
      message = "Local STT not initialized";
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

  void stop() {
    SpeechRecognitionService.stop();
  }

  bool get isRecording => SpeechRecognitionService.isRecording;

  bool isReady() => _isInitialized;

  Future<List<VoiceModel>> getVoiceModels() async {
    if (_voiceModels.isEmpty) {
      _voiceModels = await Supabase.fetchVoiceModels();
      for (var model in _voiceModels) {
        model.isDownloaded = await DownloadService.modelExists(model.fileName);
      }
    }
    return _voiceModels;
  }

  Future<bool> isModelDownloaded([String? modelName]) async {
    final currentModel = await _getModel(modelName ?? _lastDownloadedModelName);
    if (currentModel == null) {
      debugPrint("No data found for model: $modelName");
      return false;
    }
    return await DownloadService.modelExists(currentModel.fileName) && await DownloadService.modelExists(_spkModelFolder);
  }

  void dispose() {
    SpeechRecognitionService.dispose();
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