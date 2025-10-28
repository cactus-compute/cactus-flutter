import 'package:cactus/src/version.dart';

class LogRecord {
  final String eventType;
  final String? projectId;
  String? deviceId;
  final double? ttft;
  final double? tps;
  final double? responseTime;
  final String? model;
  final int? tokens;
  final String? framework = 'flutter';
  final String? frameworkVersion = packageVersion;
  final bool? success;
  final String? message;
  final String? telemetryToken;
  final int? audioDuration;

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
    this.message,
    this.telemetryToken,
    this.audioDuration
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'project_id': projectId,
      'device_id': deviceId,
      'ttft': ttft,
      'tps': tps,
      'response_time': responseTime,
      'model': model,
      'tokens': tokens,
      'framework': framework,
      'framework_version': frameworkVersion,
      'success': success,
      'message': message,
      'telemetry_token': telemetryToken,
      'audio_duration': audioDuration
    };
  }
  
  factory LogRecord.fromJson(Map<String, dynamic> json) {
    return LogRecord(
      eventType: json['event_type'] as String,
      projectId: json['project_id'] as String,
      deviceId: json['device_id'] as String?,
      ttft: json['ttft'] as double?,
      tps: json['tps'] as double?,
      responseTime: json['response_time'] as double?,
      model: json['model'] as String?,
      tokens: json['tokens'] as int?,
      success: json['success'] as bool?,
      message: json['message'] as String?,
      audioDuration: json['audio_duration'] as int?
    );
  }
}

class BufferedLogRecord {
  final LogRecord record;
  int retryCount;
  final DateTime firstAttempt;
  
  BufferedLogRecord({
    required this.record,
    this.retryCount = 0,
    required this.firstAttempt,
  });
  
  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'record': record.toJson(),
      'retryCount': retryCount,
      'firstAttempt': firstAttempt.toIso8601String(),
    };
  }
  
  factory BufferedLogRecord.fromJson(Map<String, dynamic> json) {
    return BufferedLogRecord(
      record: LogRecord.fromJson(json['record'] as Map<String, dynamic>),
      retryCount: json['retryCount'] as int,
      firstAttempt: DateTime.parse(json['firstAttempt'] as String),
    );
  }
}