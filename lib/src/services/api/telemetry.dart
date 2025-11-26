import 'package:cactus/src/models/log_record.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:cactus/src/utils/platform/device_info.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/utils/platform/ffi_utils.dart';
import 'package:cactus/src/utils/cactus_id.dart';
import 'package:flutter/foundation.dart';

class Telemetry {
  static Telemetry? _instance;
  final String? projectId;
  final String? deviceId;
  final String? cactusTelemetryToken;

  Telemetry(this.projectId, this.deviceId, this.cactusTelemetryToken) {
    _instance = this;
  }

  static bool get isInitialized => _instance != null;
  static Telemetry? get instance => _instance;

  static Future<void> init(String? telemetryToken) async {
    final String projectId = await CactusId.getProjectId();
    final String? deviceId = await fetchDeviceId();
    Telemetry(projectId, deviceId, telemetryToken);
  }

  static Future<String?> fetchDeviceId() async {
    String? deviceId = await getDeviceId();
    if (deviceId == null) {
      debugPrint('Failed to get device ID, registering device...');
      try {
        final deviceData = await getDeviceMetadata();
        return await Supabase.registerDevice(deviceData);
      } catch (e) {
        return null;
      }
    }
    return deviceId;
  }

  Future<void> logInit(bool success, String model, String message) async {
    final record = LogRecord(
      eventType: 'init',
      projectId: projectId,
      deviceId: deviceId,
      model: model,
      success: success,
      telemetryToken: cactusTelemetryToken,
      message: message
    );

    await Supabase.sendLogRecord(record);
  }

  Future<void> logCompletion(CactusCompletionResult? result, String model, {String? message, bool? success}) async {
    final record = LogRecord(
      eventType: 'completion',
      projectId: projectId,
      deviceId: deviceId,
      ttft: result?.timeToFirstTokenMs,
      tps: result?.tokensPerSecond,
      responseTime: result?.totalTimeMs,
      model: model,
      tokens: result?.totalTokens,
      success: success,
      message: message,
      telemetryToken: cactusTelemetryToken
    );

    await Supabase.sendLogRecord(record);
  }

  Future<void> logEmbedding(CactusEmbeddingResult? result, String model, {String? message, bool? success}) async {
    final record = LogRecord(
      eventType: 'embedding',
      projectId: projectId,
      deviceId: deviceId,
      model: model,
      success: result?.success,
      message: message,
      telemetryToken: cactusTelemetryToken
    );

    await Supabase.sendLogRecord(record);
  }

  Future<void> logTranscription(
    CactusTranscriptionResult? result,
    String model, {
    String? message,
    bool? success
  }) async {
    final record = LogRecord(
      eventType: 'transcription',
      projectId: projectId,
      deviceId: deviceId,
      responseTime: result?.totalTimeMs,
      model: model,
      success: success ?? result?.success,
      telemetryToken: cactusTelemetryToken,
      message: message,
      audioDuration: result?.totalTimeMs.toInt()
    );

    await Supabase.sendLogRecord(record);
  }
}