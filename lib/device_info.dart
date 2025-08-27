import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<Map<String, dynamic>> getDeviceMetadata() async {
  final deviceInfo = DeviceInfoPlugin();
  Map<String, dynamic> deviceData = {};

  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceData = {
        'model': androidInfo.model,
        'os': 'Android',
        'os_version': androidInfo.version.release,
        'device_id': androidInfo.id,
        'brand': androidInfo.brand
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceData = {
        'model': iosInfo.name,
        'os': 'iOS',
        'os_version': iosInfo.systemVersion,
        'device_id': iosInfo.identifierForVendor ?? 'unknown',
        'brand': 'apple'
      };
    }
  } catch (e) {
    // Fallback data if device info collection fails
    deviceData = {
      'model': 'Unknown',
      'type': 'unknown',
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'device_id': 'unknown',
      'error': e.toString(),
    };
  }

  return deviceData;
}
