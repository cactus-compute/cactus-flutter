import 'package:cactus/src/services/telemetry.dart';

class CactusTelemetry {
  static Future<Telemetry> init(String deviceId, {String? cactusTelemetryToken}) async {
    return Telemetry("f3a1c0b0-4c6f-4261-ac15-0c03b12d83a2", deviceId, cactusTelemetryToken);
  }

  static Future<String?> fetchDeviceId() {
    return Telemetry.fetchDeviceId();
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
