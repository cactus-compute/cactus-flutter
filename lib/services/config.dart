import 'package:cactus/src/services/api/telemetry.dart';

class CactusConfig {

  static String? telemetryToken;
  static bool isTelemetryEnabled = true;
  static String? cactusProKey;

  static setTelemetryToken(String token) {
    telemetryToken = token.isEmpty ? null : token;
  }

  static setProKey(String token) {
    cactusProKey = token.isEmpty ? null : token;
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
