import 'dart:io';

import './bindings.dart' as bindings;
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ffi';

/// Registers the app with the Cactus backend.
///
/// Returns `true` on success, `false` on failure.
Future<bool> registerApp(
    {required String encString}
) async {
  await setupAndroidDataDirectory();
  final encStringPtr = encString.toNativeUtf8();

  try {
    final result = bindings.registerApp(encStringPtr);
    return result == 1;
  } finally {
    malloc.free(encStringPtr);
  }
}

Future<void> setupAndroidDataDirectory() async {
  if (Platform.isAndroid) {
    try {
      // Get the app's data directory
      final Directory appDataDir = await getApplicationSupportDirectory();
      final String dataPath = appDataDir.path;
      
      // Convert to native string and call the function
      final Pointer<Utf8> nativeDataPath = dataPath.toNativeUtf8();
      bindings.setAndroidDataDirectory(nativeDataPath);

      // Clean up the allocated string
      malloc.free(nativeDataPath);
      
      print('Android data directory set to: $dataPath');
    } catch (e) {
      print('Failed to set Android data directory: $e');
    }
  }
}