import 'dart:io';
import 'dart:convert';

import 'package:cactus/src/models/log_record.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/log_buffer.dart';
import 'package:cactus/src/utils/ffi_utils.dart';

class _InternalModel {
  final DateTime createdAt;
  final String slug;
  final String downloadUrl;
  final int sizeMb;
  final bool supportsToolCalling;
  final bool supportsVision;
  final String name;

  _InternalModel({
    required this.createdAt,
    required this.slug,
    required this.downloadUrl,
    required this.sizeMb,
    required this.supportsToolCalling,
    required this.supportsVision,
    required this.name,
  });

  factory _InternalModel.fromJson(Map<String, dynamic> json) {
    return _InternalModel(
      createdAt: DateTime.parse(json['created_at'] as String),
      slug: json['slug'] as String,
      downloadUrl: json['download_url'] as String,
      sizeMb: json['size_mb'] as int,
      supportsToolCalling: json['supports_tool_calling'] as bool,
      supportsVision: json['supports_vision'] as bool,
      name: json['name'] as String,
    );
  }

  CactusModel toPublicModel() {
    return CactusModel(
      createdAt: createdAt,
      slug: slug,
      sizeMb: sizeMb,
      supportsToolCalling: supportsToolCalling,
      supportsVision: supportsVision,
      name: name,
    );
  }
}

class Supabase {

  static const String _supabaseUrl = 'https://ytmrvwsckmqyfpnwfcme.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0bXJ2d3Nja21xeWZwbndmY21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MzE0MjIsImV4cCI6MjA3MTMwNzQyMn0.7SjWKuOSPpu2OI7g6BEgDw6SgDgcJ0TgXkI_wm9M-PA';
  
  // Private map to store slug to downloadUrl mappings
  static final Map<String, String> _modelDownloadUrls = <String, String>{};

  static Future<void> sendLogRecord(LogRecord record) async {
    try {
      // First, try to send just the current record
      final success = await _sendLogRecordsBatch([record]);
      
      if (success) {
        print('Successfully sent current log record');
        
        // Only if current record was successful, try to send buffered records
        final failedRecords = await LogBuffer.loadFailedLogRecords();
        if (failedRecords.isNotEmpty) {
          print('Attempting to send ${failedRecords.length} buffered log records...');
          
          final bufferedSuccess = await _sendLogRecordsBatch(
            failedRecords.map((buffered) => buffered.record).toList()
          );
          
          if (bufferedSuccess) {
            await LogBuffer.clearFailedLogRecords();
            print('Successfully sent ${failedRecords.length} buffered log records');
          } else {
            for (final buffered in failedRecords) {
              await LogBuffer.handleRetryFailedLogRecord(buffered.record);
            }
            print('Failed to send buffered records, keeping them for next successful attempt');
          }
        }
      } else {
        // Current record failed, add it to buffer
        await LogBuffer.handleFailedLogRecord(record);
        print('Current log record failed, added to buffer');
      }
    } catch (e) {
      print('Error sending log record: $e');
      await LogBuffer.handleFailedLogRecord(record);
    }
  }
  
  static Future<bool> _sendLogRecordsBatch(List<LogRecord> records) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/logs');
      final request = await client.postUrl(uri);
      
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Prefer', 'return=minimal');
      
      // Send records as an array
      final body = jsonEncode(records.map((record) => record.toJson()).toList());
      request.write(body);
      
      final response = await request.close();
      print("Response from Supabase: ${response.statusCode}");
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        print("Error response body: $responseBody");
        return false;
      }
      
      await response.drain();
      return true;
    } finally {
      client.close();
    }
  }

  static Future<String?> registerDevice(Map<String, dynamic> deviceData) async {
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

  static Future<List<CactusModel>> fetchModels() async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/rest/v1/models?select=*');
      final request = await client.getUrl(uri);
      
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = jsonDecode(responseBody) as List<dynamic>;
        
        _modelDownloadUrls.clear();
        
        final models = jsonList.map((json) {
          final internalModel = _InternalModel.fromJson(json as Map<String, dynamic>);
          _modelDownloadUrls[internalModel.slug] = internalModel.downloadUrl;
          return internalModel.toPublicModel();
        }).toList();
        
        return models;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<String?> getModelDownloadUrl(String slug) async {
    if (_modelDownloadUrls.isEmpty) {
      await fetchModels();
    }
    return _modelDownloadUrls[slug];
  }
}