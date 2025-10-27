import 'package:cactus/models/types.dart';
import 'package:cactus/src/utils/models/download.dart';
import 'package:cactus/src/services/transcription/vosk.dart';
import 'package:cactus/src/services/transcription/transcription_provider.dart';

class VoskTranscriptionProvider extends BaseTranscriptionProvider {
  // Speaker model is universal, no need to change it for different languages
  static const String _spkModelFolder = "vosk-model-spk-0.4";
  static const String _spkModelUrl = "https://alphacephei.com/vosk/models/vosk-model-spk-0.4.zip";

  @override
  String get providerName => 'vosk';

  @override
  String get defaultModel => 'vosk-en-us';

  @override
  Future<bool> initializeService(String modelPath, {String? additionalModelPath}) async {
    return await VoskService.initialize(modelPath, additionalModelPath ?? '');
  }

  @override
  Future<SpeechRecognitionResult?> performRecognition(
    SpeechRecognitionParams params,
    String? filePath,
  ) async {
    return await VoskService.recognize(
      params: params,
      filePath: filePath,
    );
  }

  @override
  bool get serviceReady => true;

  @override
  bool get serviceRecording => VoskService.isCurrentlyRecording;

  @override
  void stopService() {
    VoskService.stop();
  }

  @override
  void disposeService() {
    VoskService.dispose();
  }

  @override
  Future<List<DownloadTask>> buildDownloadTasks(VoiceModel model, String modelName) async {
    final tasks = <DownloadTask>[];

    if (!await DownloadService.modelExists(model.slug)) {
      tasks.add(DownloadTask(
        url: model.url,
        filename: "$modelName.zip",
        folder: modelName,
      ));
    }

    if (!await DownloadService.modelExists(_spkModelFolder)) {
      tasks.add(DownloadTask(
        url: _spkModelUrl,
        filename: "$_spkModelFolder.zip",
        folder: _spkModelFolder,
      ));
    }

    return tasks;
  }

  @override
  String buildModelPath(String appDocPath, String model) {
    return '$appDocPath/models/$model';
  }

  @override
  String? getAdditionalModelPath(String appDocPath, String model) {
    return '$appDocPath/models/$_spkModelFolder';
  }

  @override
  Future<bool> isModelDownloaded({required String modelName}) async {
    return await DownloadService.modelExists(modelName) &&
           await DownloadService.modelExists(_spkModelFolder);
  }
}
