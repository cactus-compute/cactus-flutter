import 'dart:io';
import 'dart:convert';

import 'package:cactus/models/log_record.dart';
import 'package:cactus/models/models.dart';
import 'package:cactus/utils/ffi_utils.dart';

class Supabase {

  static const String _supabaseUrl = 'https://ytmrvwsckmqyfpnwfcme.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0bXJ2d3Nja21xeWZwbndmY21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MzE0MjIsImV4cCI6MjA3MTMwNzQyMn0.7SjWKuOSPpu2OI7g6BEgDw6SgDgcJ0TgXkI_wm9M-PA';

  static Future<void> sendLogRecord(LogRecord record) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('$_supabaseUrl/rest/v1/logs');
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

  static Future<List<Model>> fetchModels() async {
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
        final models = jsonList.map((json) => Model.fromJson(json as Map<String, dynamic>)).toList();
        return models;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}