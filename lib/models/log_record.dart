import 'package:cactus/src/version.dart';

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