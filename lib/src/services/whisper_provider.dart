import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/services/whisper.dart';
import 'package:cactus/src/services/cactus_id.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:cactus/src/services/transcription_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_new/download_model.dart';

import '../services/telemetry.dart';

class WhisperTranscriptionProvider implements TranscriptionProviderInterface {
  bool _isInitialized = false;
  String _currentModel = "tiny";

  @override
  Future<bool> download({
    String model = "tiny",
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    // Whisper models are downloaded automatically by whisper_flutter_new
    // We just store the model name for later use
    _currentModel = model;
    return true;
  }

  @override
  Future<bool> init({String? model}) async {
    _isInitialized = false;
    final modelToUse = model ?? _currentModel;
    
    try {
      if (!Telemetry.isInitialized) {
        final String projectId = await CactusId.getProjectId();
        final String? deviceId = await Telemetry.fetchDeviceId();
        Telemetry(projectId, deviceId, CactusTelemetry.telemetryToken);
      }

      WhisperModel whisperModel;
      switch (modelToUse.toLowerCase()) {
        case 'tiny':
          whisperModel = WhisperModel.tiny;
          break;
        case 'base':
          whisperModel = WhisperModel.base;
          break;
        case 'small':
          whisperModel = WhisperModel.small;
          break;
        case 'medium':
          whisperModel = WhisperModel.medium;
          break;
        default:
          whisperModel = WhisperModel.tiny;
      }

      _isInitialized = await WhisperService.initialize(model: whisperModel);

      if (Telemetry.isInitialized) {
        final message = _isInitialized ? "" : "Failed to initialize Whisper model: $modelToUse";
        Telemetry.instance?.logInit(
          _isInitialized,
          CactusInitParams(model: modelToUse),
          message,
        );
      }

      if (_isInitialized) {
        _currentModel = modelToUse;
        debugPrint('Whisper initialized successfully via WhisperService');
      } else {
        debugPrint('Failed to initialize Whisper via WhisperService');
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

    if (_isInitialized && WhisperService.isReady) {
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
        CactusInitParams(model: _currentModel),
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
  bool get isRecording => WhisperService.isRecording;

  @override
  bool isReady() => _isInitialized && WhisperService.isReady;

  @override
  Future<List<VoiceModel>> getVoiceModels() async {
    // Fetch Whisper models from Supabase
    return await Supabase.fetchVoiceModels(provider: 'whisper');
  }

  @override
  Future<bool> isModelDownloaded([String? modelName]) async {
    // Whisper models are downloaded automatically by the package
    return true;
  }

  @override
  void dispose() {
    WhisperService.dispose();
    _isInitialized = false;
  }

}