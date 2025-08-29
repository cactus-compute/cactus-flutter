import 'package:cactus/src/services/telemetry.dart';

class CactusTelemetry {
  static Telemetry init(String projectId, String deviceId) {
    return Telemetry(projectId, deviceId);
  }

  static Future<String?> fetchDeviceId() {
    return Telemetry.fetchDeviceId();
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
