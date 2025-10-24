import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/api/telemetry.dart';
import 'package:cactus/src/services/transcription/transcription_provider.dart';
import 'package:cactus/src/services/transcription/vosk_provider.dart';
import 'package:cactus/src/services/transcription/whisper_provider.dart';

class CactusSTT {
  final TranscriptionProvider _provider;
  late final TranscriptionProviderInterface _providerInstance;

  CactusSTT({TranscriptionProvider provider = TranscriptionProvider.vosk}) 
      : _provider = provider {
    _initializeProvider();
  }

  void _initializeProvider() {
    switch (_provider) {
      case TranscriptionProvider.vosk:
        _providerInstance = VoskTranscriptionProvider();
        break;
      case TranscriptionProvider.whisper:
        _providerInstance = WhisperTranscriptionProvider();
        break;
    }
  }

  /// Get the current transcription provider
  TranscriptionProvider get provider => _provider;

  Future<bool> download({
    String model = "",
    CactusProgressCallback? downloadProcessCallback,
  }) async {
    // Set default model based on provider
    String defaultModel = model;
    if (model.isEmpty) {
      switch (_provider) {
        case TranscriptionProvider.vosk:
          defaultModel = "vosk-en-us";
          break;
        case TranscriptionProvider.whisper:
          defaultModel = "tiny";
          break;
      }
    }
    
    return await _providerInstance.download(
      model: defaultModel,
      downloadProcessCallback: downloadProcessCallback,
    );
  }

  Future<bool> init({String? model}) async {
    if (!Telemetry.isInitialized) {
      await Telemetry.init(CactusTelemetry.telemetryToken);
    }
    return await _providerInstance.init(model: model);
  }

  Future<SpeechRecognitionResult?> transcribe({
    SpeechRecognitionParams? params,
    String? filePath
  }) async {
    return await _providerInstance.transcribe(
      params: params,
      filePath: filePath,
    );
  }

  void stop() {
    _providerInstance.stop();
  }

  bool get isRecording => _providerInstance.isRecording;

  bool isReady() => _providerInstance.isReady();

  Future<List<VoiceModel>> getVoiceModels() async {
    return await _providerInstance.getVoiceModels();
  }

  Future<bool> isModelDownloaded([String? modelName]) async {
    return await _providerInstance.isModelDownloaded(modelName);
  }

  void dispose() {
    _providerInstance.dispose();
  }
}