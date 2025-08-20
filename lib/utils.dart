import 'dart:ffi';

import './bindings.dart' as bindings;
import 'package:ffi/ffi.dart';

/// Registers the app with the Cactus backend.
///
/// Returns `true` on success, `false` on failure.
bool registerApp(
    {required String telemetryToken,
    String? enterpriseKey,
    required String deviceMetadata}
) {
  final telemetryTokenPtr = telemetryToken.toNativeUtf8();
  final enterpriseKeyPtr = enterpriseKey?.toNativeUtf8() ?? nullptr;
  final deviceMetadataPtr = deviceMetadata.toNativeUtf8();

  try {
    final result = bindings.registerApp(
        telemetryTokenPtr, enterpriseKeyPtr, deviceMetadataPtr);
    return result == 1;
  } finally {
    malloc.free(telemetryTokenPtr);
    if (enterpriseKeyPtr != nullptr) {
      malloc.free(enterpriseKeyPtr);
    }
    malloc.free(deviceMetadataPtr);
  }
}

/// Retrieves all entries from the Cactus backend.
List<String> getAllEntries() {
  final resultPtr = bindings.getAllEntries();
  final result = resultPtr.toDartString();
  return result.split(',');
}