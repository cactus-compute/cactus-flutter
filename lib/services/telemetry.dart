import 'dart:io';

import 'package:cactus/models/log_record.dart';
import 'package:cactus/services/supabase.dart';
import 'package:cactus/utils/device_info.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/utils/ffi_utils.dart';

class CactusTelemetry {
  static CactusTelemetry? _instance;
  final String projectId;
  final String deviceId;

  CactusTelemetry(this.projectId, this.deviceId) {
    _instance = this;
  }

  static bool get isInitialized => _instance != null;
  static CactusTelemetry? get instance => _instance;

  static Future<String?> fetchDeviceId() async {
    String? deviceId = await getDeviceId();
    if (deviceId == null) {
      print('Failed to get device ID, registering device...');
      try {
        final deviceData = await getDeviceMetadata();
        return await Supabase.registerDevice(deviceData);
      } catch (e) {
        return null;
      }
    }
    return deviceId;
  }

  Future<void> logInit(bool success, CactusInitParams options) async {
    print("init log");
    final record = LogRecord(
      eventType: 'init',
      projectId: projectId,
      deviceId: deviceId,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      success: success
    );

    await Supabase.sendLogRecord(record);
  }

  Future<void> logCompletion(CactusCompletionResult? result, CactusInitParams options, {String? message, bool? success}) async {
    final record = LogRecord(
      eventType: 'completion',
      projectId: projectId,
      deviceId: deviceId,
      ttft: result?.timeToFirstTokenMs,
      tps: result?.tokensPerSecond,
      responseTime: result?.totalTimeMs,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      tokens: result?.totalTokens.toDouble(),
      success: success,
      message: message
    );

    await Supabase.sendLogRecord(record);
  }

  static String _getFilename(String? path) {
    if (path == null || path.isEmpty) return 'unknown';
    try {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'unknown';
      }
      return path.split(Platform.pathSeparator).last;
    } catch (e) {
      return 'unknown';
    }
  }
}