import 'dart:io';
import 'dart:convert';

import 'package:cactus/src/utils/models/model_cache.dart';
import 'package:cactus/src/version.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:flutter/foundation.dart';
import 'package:cactus/src/models/log_record.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/utils/logging/log_buffer.dart';
import 'package:cactus/src/utils/platform/ffi_utils.dart';

class Supabase {

  static const String _supabaseUrl = 'https://vlqqczxwyaodtcdmdmlw.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZscXFjenh3eWFvZHRjZG1kbWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MTg2MzIsImV4cCI6MjA2NzA5NDYzMn0.nBzqGuK9j6RZ6mOPWU2boAC_5H9XDs-fPpo5P3WZYbI';

  static Future<void> sendLogRecord(LogRecord record) async {
    if (!CactusTelemetry.isTelemetryEnabled) {
      return;
    }
    
    try {
      final success = await _sendLogRecordsBatch([record]);
      
      if (success) {
        debugPrint('Successfully sent current log record');
        
        final failedRecords = await LogBuffer.loadFailedLogRecords();
        if (failedRecords.isNotEmpty) {
          debugPrint('Attempting to send ${failedRecords.length} buffered log records...');
          
          // Get current device ID and update all buffered records
          final currentDeviceId = await getDeviceId();
          final updatedRecords = failedRecords.map((buffered) {
            buffered.record.deviceId = currentDeviceId;
            return buffered.record;
          }).toList();
          
          final bufferedSuccess = await _sendLogRecordsBatch(updatedRecords);
          
          if (bufferedSuccess) {
            await LogBuffer.clearFailedLogRecords();
            debugPrint('Successfully sent ${failedRecords.length} buffered log records');
          } else {
            for (final buffered in failedRecords) {
              await LogBuffer.handleRetryFailedLogRecord(buffered.record);
            }
            debugPrint('Failed to send buffered records, keeping them for next successful attempt');
          }
        }
      } else {
        await LogBuffer.handleFailedLogRecord(record);
        debugPrint('Current log record failed, added to buffer');
      }
    } catch (e) {
      debugPrint('Error sending log record: $e');
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
      request.headers.set('Content-Profile', 'cactus');
      
      final body = jsonEncode(records.map((record) => record.toJson()).toList());
      request.write(body);
      
      final response = await request.close();
      debugPrint("Response from Supabase: ${response.statusCode}");
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        debugPrint("Error response body: $responseBody");
        return false;
      }
      
      await response.drain();
      return true;
    } finally {
      client.close();
    }
  }

  static Future<String?> registerDevice(Map<String, dynamic> deviceData) async {
    if (!CactusTelemetry.isTelemetryEnabled) {
      return 'telemetry-disabled';
    }
    
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
        debugPrint('Device registered successfully');        
        final deviceId = await registerApp(responseBody);
        return deviceId;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<CactusModel?> getModel(String slug) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/functions/v1/get-models?slug=$slug&sdk_name=flutter&sdk_version=$packageVersion');
      final request = await client.getUrl(uri);
      
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final dynamic json = jsonDecode(responseBody);
        final model = CactusModel.fromJson(json as Map<String, dynamic>);
        ModelCache.saveModel(model);
        return model;
      }
      return ModelCache.loadModel(slug);
    } catch (e) {
      debugPrint('Error fetching model information: $e');
      return ModelCache.loadModel(slug);
    }
  }

  static Future<List<CactusModel>> fetchModels() async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/functions/v1/get-models?sdk_name=flutter&sdk_version=$packageVersion');
      final request = await client.getUrl(uri);
      
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> jsonList = jsonDecode(responseBody) as List<dynamic>;
        
        final models = jsonList.map((json) {
          final model = CactusModel.fromJson(json as Map<String, dynamic>);
          return model;
        }).toList();
        return models;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return [];
    }
  }

  static Future<List<VoiceModel>> fetchVoiceModels({String? provider}) async {
    final client = HttpClient();

    try {
      String url = '$_supabaseUrl/rest/v1/whisper?select=*';
      if (provider != null) {
        url += '&provider=eq.$provider';
      }
      
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('apikey', _supabaseKey);
      request.headers.set('Authorization', 'Bearer $_supabaseKey');
      request.headers.set('Accept-Profile', 'cactus');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        debugPrint('Fetched voice models for provider $provider: $responseBody');
        final List<dynamic> data = json.decode(responseBody);
        return data.map((json) => VoiceModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch voice models: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}