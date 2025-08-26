import 'dart:io';
import 'dart:convert';
import './types.dart';

class LogRecord {
  final String eventType;
  final String projectId;
  final String deviceId;
  final double? ttfs;
  final double? tps;
  final double responseTime;
  final String model;
  final double tokens;
  final String? mode;

  LogRecord({
    required this.eventType,
    required this.projectId,
    required this.deviceId,
    this.ttfs,
    this.tps,
    required this.responseTime,
    required this.model,
    required this.tokens,
    this.mode,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType,
      'project_id': projectId,
      'device_id': deviceId,
      if (ttfs != null) 'ttfs': ttfs,
      if (tps != null) 'tps': tps,
      'response_time': responseTime,
      'model': model,
      'tokens': tokens,
      if (mode != null) 'mode': mode,
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

  Future<void> logCompletion(CactusCompletionResult result, CactusInitParams options) async {
    final record = LogRecord(
      eventType: 'completion',
      projectId: projectId,
      deviceId: deviceId,
      ttfs: result.timeToFirstTokenMs,
      tps: result.tokensPerSecond,
      responseTime: result.totalTimeMs,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      tokens: result.totalTokens.toDouble(),
      mode: 'chat',
    );

    await _sendLogRecord(record);
  }

  Future<void> logError(Object? error, CactusInitParams options) async {
    final record = LogRecord(
      eventType: 'error',
      projectId: projectId,
      deviceId: deviceId,
      responseTime: 0.0,
      model: _getFilename(options.modelPath ?? options.modelUrl),
      tokens: 0.0,
      mode: error.runtimeType.toString(),
    );

    await _sendLogRecord(record);
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
}