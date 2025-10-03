import 'package:cactus/models/types.dart';

abstract class TranscriptionProviderInterface {
  Future<bool> download({
    String model = "",
    CactusProgressCallback? downloadProcessCallback,
  });

  Future<bool> init({String? model});

  Future<SpeechRecognitionResult?> transcribe({
    SpeechRecognitionParams? params,
    String? filePath,
  });

  void stop();

  bool get isRecording;

  bool isReady();

  Future<List<VoiceModel>> getVoiceModels();

  Future<bool> isModelDownloaded([String? modelName]);

  void dispose();
}