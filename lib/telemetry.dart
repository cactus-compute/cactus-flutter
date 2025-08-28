import 'dart:io';
import 'dart:convert';

import 'package:cactus/device_info.dart';
import 'package:cactus/src/version.dart';
import 'package:cactus/utils.dart';

import './types.dart';

class LogRecord {
  final String eventType;
  final String projectId;
  final String deviceId;
  final double? ttft;
  final double? tps;
  final double? responseTime;
  final String model;
  final double? tokens;
  final String? framework = 'flutter';
  final String? frameworkVersion = packageVersion;
  final bool? success;
  final String? message;

  LogRecord({
    required this.eventType,
    required this.projectId,
    required this.deviceId,
    this.ttft,
    this.tps,
    this.responseTime,
    required this.model,
    this.tokens,
    this.success,
    this.message
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'project_id': projectId,
      'device_id': deviceId,
      if (ttft != null) 'ttft': ttft,
      if (tps != null) 'tps': tps,
      'response_time': responseTime,
      'model': model,
      'tokens': tokens,
      'framework': framework,
      'framework_version': frameworkVersion,
      if (success != null) 'success': success,
      if (message != null) 'message': message,
    };
  }
}

class CactusTelemetry {
  static CactusTelemetry? _instance;
  final String projectId;
  final String deviceId;
  
  // Hardcoded Supabase configuration
  static const String _supabaseUrl = 'https://ytmrvwsckmqyfpnwfcme.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0bXJ2d3Nja21xeWZwbndmY21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MzE0MjIsImV4cCI6MjA3MTMwNzQyMn0.7SjWKuOSPpu2OI7g6BEgDw6SgDgcJ0TgXkI_wm9M-PA';
  static const String _logsTable = 'logs';

  CactusTelemetry(this.projectId, this.deviceId) {
    _instance = this;
  }

  static bool get isInitialized => _instance != null;
  static CactusTelemetry? get instance => _instance;

  static Future<String?> fetchDeviceId() async {
    String? deviceId = await getDeviceId();
    if (deviceId == null) {
      print('Failed to get device ID, registering device...');
      try {
        final deviceData = await getDeviceMetadata();
        return await _registerDevice(deviceData);
      } catch (e) {
        return null;
      }
    }
    return deviceId;
  }

  Future<void> logInit(bool success, CactusInitParams options) async {
    print("init log");
    final record = LogRecord(
      eventType: 'init',
      projectId: projectId,
      deviceId: deviceId,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      success: success
    );

    await _sendLogRecord(record);
  }

  Future<void> logCompletion(CactusCompletionResult? result, CactusInitParams options, {String? message, bool? success}) async {
    final record = LogRecord(
      eventType: 'completion',
      projectId: projectId,
      deviceId: deviceId,
      ttft: result?.timeToFirstTokenMs,
      tps: result?.tokensPerSecond,
      responseTime: result?.totalTimeMs,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      tokens: result?.totalTokens.toDouble(),
      success: success,
      message: message
    );

    await _sendLogRecord(record);
  }

  static String _getFilename(String? path) {
    if (path == null || path.isEmpty) return 'unknown';
    try {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'unknown';
      }
      return path.split(Platform.pathSeparator).last;
    } catch (e) {
      return 'unknown';
    }
  }

  Future<void> _sendLogRecord(LogRecord record) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/rest/v1/$_logsTable');
      final request = await client.postUrl(uri);
      
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Prefer', 'return=minimal');
      
      final body = jsonEncode(record.toJson());
      request.write(body);
      
      final response = await request.close();
      print("Response from Supabase: ${response.statusCode}");
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        print("Error response body: $responseBody");
      }
      
      await response.drain();
      client.close();
    } catch (e) {
      print('Error sending log record: $e');
    }
  }

  static Future<String?> _registerDevice(Map<String, dynamic> deviceData) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/functions/v1/device-registration');
      final request = await client.postUrl(uri);
      
      // Set headers
      request.headers.set('Content-Type', 'application/json');
      
      // Send device data wrapped in device_data object as per API spec
      final body = jsonEncode({
        'device_data': deviceData
      });
      request.write(body);
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        print('Device registered successfully');        
        final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final deviceId = await registerApp(encString: responseJson['encrypted_payload']);
        return deviceId;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}