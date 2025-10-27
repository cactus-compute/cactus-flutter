import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/transcription/whisper.dart';
import 'package:cactus/src/utils/models/download.dart';
import 'package:cactus/src/services/transcription/transcription_provider.dart';

class WhisperTranscriptionProvider extends BaseTranscriptionProvider {
  @override
  String get providerName => 'whisper';

  @override
  String get defaultModel => 'whisper-tiny';

  @override
  Future<bool> initializeService(String modelPath, {String? additionalModelPath}) async {
    return await WhisperService.initialize(modelPath: modelPath);
  }

  @override
  Future<SpeechRecognitionResult?> performRecognition(
    SpeechRecognitionParams params,
    String? filePath,
  ) async {
    return await WhisperService.recognize(
      params: params,
      filePath: filePath,
    );
  }

  @override
  bool get serviceReady => WhisperService.isServiceReady;

  @override
  bool get serviceRecording => WhisperService.isCurrentlyRecording;

  @override
  void stopService() {
    WhisperService.stop();
  }

  @override
  void disposeService() {
    WhisperService.dispose();
  }

  @override
  Future<List<DownloadTask>> buildDownloadTasks(VoiceModel model, String modelName) async {
    final tasks = <DownloadTask>[];

    if (!await DownloadService.modelExists(model.slug)) {
      tasks.add(DownloadTask(
        url: model.url,
        filename: "$modelName.bin",
        folder: modelName,
      ));
    }

    return tasks;
  }

  @override
  String buildModelPath(String appDocPath, String model) {
    return '$appDocPath/models/$model/$model.bin';
  }
}
