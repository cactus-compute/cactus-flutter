import 'package:cactus/src/services/api/telemetry.dart';

class CactusTelemetry {

  static String? telemetryToken;

  static setTelemetryToken(String token) {
    telemetryToken = token.isEmpty ? null : token;
  }

  static Future<String?> fetchDeviceId() {
    return Telemetry.fetchDeviceId();
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
