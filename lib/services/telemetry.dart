import 'package:cactus/src/services/telemetry.dart';

class CactusTelemetry {

  static String telemetryToken = "";

  static setTelemetryToken(String token) {
    telemetryToken = token;
  }

  static Future<String?> fetchDeviceId() {
    return Telemetry.fetchDeviceId();
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
