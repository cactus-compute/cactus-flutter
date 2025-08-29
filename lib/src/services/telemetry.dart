import 'package:cactus/src/models/log_record.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:cactus/src/utils/device_info.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/utils/ffi_utils.dart';

class Telemetry {
  static Telemetry? _instance;
  final String projectId;
  final String deviceId;

  Telemetry(this.projectId, this.deviceId) {
    _instance = this;
  }

  static bool get isInitialized => _instance != null;
  static Telemetry? get instance => _instance;

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
    final record = LogRecord(
      eventType: 'init',
      projectId: projectId,
      deviceId: deviceId,
      model: options.model,
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
      model: options.model,
      tokens: result?.totalTokens.toDouble(),
      success: success,
      message: message
    );

    await Supabase.sendLogRecord(record);
  }
}