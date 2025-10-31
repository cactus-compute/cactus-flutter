import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> getDeviceMetadata() async {
  final deviceInfo = DeviceInfoPlugin();
  Map<String, dynamic> deviceData = {};

  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final androidID = await const AndroidId().getId();
      deviceData = {
        'model': androidInfo.model,
        'os': 'Android',
        'os_version': androidInfo.version.release,
        'device_id': androidID,
        'brand': androidInfo.brand
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      debugPrint("model name: ${iosInfo.modelName}, id: ${iosInfo.identifierForVendor}");
      deviceData = {
        'model': iosInfo.modelName,
        'os': 'iOS',
        'os_version': iosInfo.systemVersion,
        'device_id': iosInfo.identifierForVendor ?? 'unknown',
        'brand': 'apple'
      };
    } else if (Platform.isMacOS) {
      final macosInfo = await deviceInfo.macOsInfo;
      deviceData = {
        'model': macosInfo.model,
        'os': 'macOS',
        'os_version': macosInfo.osRelease,
        'device_id': macosInfo.systemGUID ?? 'unknown',
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
