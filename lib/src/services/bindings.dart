import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:cactus/src/models/binding.dart';
import 'package:ffi/ffi.dart';

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

final cactusTranscribe = cactusLib
    .lookup<NativeFunction<CactusTranscribeNative>>('cactus_transcribe')
    .asFunction<CactusTranscribeDart>();

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
