import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:cactus/src/models/binding.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

String _getLibraryPath(String libName) {
  if (Platform.isIOS || Platform.isMacOS) {
    return '$libName.framework/$libName';
  }
  if (Platform.isAndroid) {
    return 'lib$libName.so';
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final DynamicLibrary cactusLib = DynamicLibrary.open(_getLibraryPath('cactus'));

final cactusInit = cactusLib
    .lookup<NativeFunction<CactusInitNative>>('cactus_init')
    .asFunction<CactusInitDart>();

final cactusComplete = cactusLib
    .lookup<NativeFunction<CactusCompleteNative>>('cactus_complete')
    .asFunction<CactusCompleteDart>();

final cactusDestroy = cactusLib
    .lookup<NativeFunction<CactusDestroyNative>>('cactus_destroy')
    .asFunction<CactusDestroyDart>();

final cactusEmbed = cactusLib
    .lookup<NativeFunction<CactusEmbedNative>>('cactus_embed')
    .asFunction<CactusEmbedDart>();

final DynamicLibrary cactusUtil = DynamicLibrary.open(_getLibraryPath('cactus_util'));

final registerApp = cactusUtil
    .lookup<NativeFunction<RegisterAppNative>>('register_app')
    .asFunction<RegisterAppDart>();

final setAndroidDataDirectory = cactusUtil
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('set_android_data_directory')
    .asFunction<void Function(Pointer<Utf8>)>();

final getDeviceId = cactusUtil
    .lookup<NativeFunction<GetDeviceIdNative>>('get_device_id')
    .asFunction<GetDeviceIdDart>();

// Vosk function bindings - only available on Android
final DynamicLibrary? voskLib = Platform.isAndroid ? (() {
  try {
    return DynamicLibrary.open(_getLibraryPath('vosk'));
  } catch (e) {
    debugPrint('Warning: Could not load Vosk library: $e');
    return null;
  }
})() : null;

final voskModelNew = voskLib?.lookup<NativeFunction<VoskModelNewNative>>('vosk_model_new')
    .asFunction<VoskModelNewDart>();

final voskModelFree = voskLib?.lookup<NativeFunction<VoskModelFreeNative>>('vosk_model_free')
    .asFunction<VoskModelFreeDart>();

final voskSpkModelNew = voskLib?.lookup<NativeFunction<VoskSpkModelNewNative>>('vosk_spk_model_new')
    .asFunction<VoskSpkModelNewDart>();

final voskSpkModelFree = voskLib?.lookup<NativeFunction<VoskSpkModelFreeNative>>('vosk_spk_model_free')
    .asFunction<VoskSpkModelFreeDart>();

final voskRecognizerNewSpk = voskLib?.lookup<NativeFunction<VoskRecognizerNewSpkNative>>('vosk_recognizer_new_spk')
    .asFunction<VoskRecognizerNewSpkDart>();

final voskRecognizerAcceptWaveform = voskLib?.lookup<NativeFunction<VoskRecognizerAcceptWaveformNative>>('vosk_recognizer_accept_waveform')
    .asFunction<VoskRecognizerAcceptWaveformDart>();

final voskRecognizerResult = voskLib?.lookup<NativeFunction<VoskRecognizerResultNative>>('vosk_recognizer_result')
    .asFunction<VoskRecognizerResultDart>();

final voskRecognizerFinalResult = voskLib?.lookup<NativeFunction<VoskRecognizerFinalResultNative>>('vosk_recognizer_final_result')
    .asFunction<VoskRecognizerFinalResultDart>();

final voskRecognizerPartialResult = voskLib?.lookup<NativeFunction<VoskRecognizerPartialResultNative>>('vosk_recognizer_partial_result')
    .asFunction<VoskRecognizerPartialResultDart>();

final voskRecognizerFree = voskLib?.lookup<NativeFunction<VoskRecognizerFreeNative>>('vosk_recognizer_free')
    .asFunction<VoskRecognizerFreeDart>();

// Whisper function bindings - available on both platforms
final DynamicLibrary whisperLib = DynamicLibrary.open(_getLibraryPath('whisper'));


final whisperInitFromFile = whisperLib.lookup<NativeFunction<WhisperInitFromFileNative>>('whisper_init_from_file')
    .asFunction<WhisperInitFromFileDart>();

final whisperFree = whisperLib.lookup<NativeFunction<WhisperFreeNative>>('whisper_free')
    .asFunction<WhisperFreeDart>();

final whisperFreeParams = whisperLib.lookup<NativeFunction<WhisperFreeParamsNative>>('whisper_free_params')
    .asFunction<WhisperFreeParamsDart>();

final whisperFullDefaultParamsByRef = whisperLib.lookup<NativeFunction<WhisperFullDefaultParamsByRefNative>>('whisper_full_default_params_by_ref')
    .asFunction<WhisperFullDefaultParamsByRefDart>();

final whisperFull = whisperLib.lookup<NativeFunction<WhisperFullNative>>('whisper_full')
    .asFunction<WhisperFullDart>();

final whisperFullNSegments = whisperLib.lookup<NativeFunction<WhisperFullNSegmentsNative>>('whisper_full_n_segments')
    .asFunction<WhisperFullNSegmentsDart>();

final whisperFullGetSegmentText = whisperLib.lookup<NativeFunction<WhisperFullGetSegmentTextNative>>('whisper_full_get_segment_text')
    .asFunction<WhisperFullGetSegmentTextDart>();

final whisperFullGetSegmentT0 = whisperLib.lookup<NativeFunction<WhisperFullGetSegmentT0Native>>('whisper_full_get_segment_t0')
    .asFunction<WhisperFullGetSegmentT0Dart>();

final whisperFullGetSegmentT1 = whisperLib.lookup<NativeFunction<WhisperFullGetSegmentT1Native>>('whisper_full_get_segment_t1')
    .asFunction<WhisperFullGetSegmentT1Dart>();
