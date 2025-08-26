import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

// Opaque pointer type for the model handle
final class CactusModelOpaque extends Opaque {}
typedef CactusModel = Pointer<CactusModelOpaque>;

// Function type definitions
typedef CactusInitNative = CactusModel Function(Pointer<Utf8> modelPath);
typedef CactusInitDart = CactusModel Function(Pointer<Utf8> modelPath);

typedef CactusCompleteNative = Int32 Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    Size bufferSize,
    Pointer<Utf8> optionsJson);
typedef CactusCompleteDart = int Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    int bufferSize,
    Pointer<Utf8> optionsJson);

typedef CactusDestroyNative = Void Function(CactusModel model);
typedef CactusDestroyDart = void Function(CactusModel model);

typedef RegisterAppNative = Int32 Function(
    Pointer<Utf8> encData);
typedef RegisterAppDart = int Function(
    Pointer<Utf8> encData);

typedef GetAllEntriesNative = Pointer<Utf8> Function();
typedef GetAllEntriesDart = Pointer<Utf8> Function();

// Helper function to get the library path based on platform
String _getLibraryPath(String libName) {
  if (Platform.isIOS || Platform.isMacOS) {
    return '$libName.framework/$libName';
  }
  if (Platform.isAndroid) {
    return 'lib$libName.so';
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

// Load the dynamic library
final DynamicLibrary cactusLib = DynamicLibrary.open(_getLibraryPath('cactus'));

// Bind the native functions
final cactusInit = cactusLib
    .lookup<NativeFunction<CactusInitNative>>('cactus_init')
    .asFunction<CactusInitDart>();

final cactusComplete = cactusLib
    .lookup<NativeFunction<CactusCompleteNative>>('cactus_complete')
    .asFunction<CactusCompleteDart>();

final cactusDestroy = cactusLib
    .lookup<NativeFunction<CactusDestroyNative>>('cactus_destroy')
    .asFunction<CactusDestroyDart>();

final DynamicLibrary cactusUtil = DynamicLibrary.open(_getLibraryPath('cactus_util'));

final registerApp = cactusUtil
    .lookup<NativeFunction<RegisterAppNative>>('register_app')
    .asFunction<RegisterAppDart>();

final setAndroidDataDirectory = cactusUtil
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('set_android_data_directory')
    .asFunction<void Function(Pointer<Utf8>)>();
