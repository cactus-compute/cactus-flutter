import 'package:cactus/src/services/cactus_id.dart';
import 'package:cactus/src/services/telemetry.dart';

class CactusTelemetry {
  static Future<Telemetry> init(String deviceId, {String? cactusTelemetryToken}) async {
    final String projectId = await CactusId.getProjectId();
    return Telemetry(projectId, deviceId, cactusTelemetryToken);
  }

  static Future<String?> fetchDeviceId() {
    return Telemetry.fetchDeviceId();
  }

  static bool get isInitialized => Telemetry.isInitialized;
}
