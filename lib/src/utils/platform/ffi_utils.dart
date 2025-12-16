import 'dart:io';

import 'package:cactus/cactus.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:cactus/src/services/bindings.dart' as bindings;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ffi';


Future<String?> registerApp(
  String encString
) async {
  await _setupAndroidDataDirectory();
  final encStringPtr = encString.toNativeUtf8();

  try {
    final resultPtr = bindings.registerApp(encStringPtr);
    
    if (resultPtr == nullptr) {
      return null;
    }
    
    // Convert the returned C string to Dart string
    final resultString = resultPtr.toDartString();
    
    // Note: We don't free resultPtr here as it's managed by the C library
    return resultString;
  } finally {
    malloc.free(encStringPtr);
  }
}

Future<String?> getDeviceId() async {
  try {
    await _setupAndroidDataDirectory();
    final currentToken = CactusConfig.cactusProKey ?? '';
    final currentTokenPtr = currentToken.toNativeUtf8();
    final resultPtr = bindings.getDeviceId(currentTokenPtr);

    if (resultPtr == nullptr) {
      malloc.free(currentTokenPtr);
      return null;
    }
    final deviceId = resultPtr.toDartString();
    malloc.free(resultPtr);
    malloc.free(currentTokenPtr);
    if (deviceId.contains('|')) {
      final parts = deviceId.split('|');
      CactusConfig.setProKey(parts[1]);
      return await Supabase.registerDevice(deviceId: parts[0]);
    }
    return deviceId;
  } catch (e) {
    debugPrint('Error getting device ID: $e');
    return null;
  }
}

Future<void> _setupAndroidDataDirectory() async {
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
    } catch (e) {
      debugPrint('Failed to set Android data directory: $e');
    }
  }
}