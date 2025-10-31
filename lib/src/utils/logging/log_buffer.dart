import 'dart:convert';

import 'package:cactus/src/models/log_record.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogBuffer {
  static const String _failedLogRecordsKey = 'cactus_failed_log_records';
  static const int _maxRetries = 3;
  
  static Future<List<BufferedLogRecord>> loadFailedLogRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_failedLogRecordsKey);
      if (jsonString == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => BufferedLogRecord.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading failed log records: $e');
      return [];
    }
  }
  
  static Future<void> clearFailedLogRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_failedLogRecordsKey);
    } catch (e) {
      debugPrint('Error clearing failed log records: $e');
    }
  }

  static Future<void> handleFailedLogRecord(LogRecord record) async {
    final failedRecords = await loadFailedLogRecords();
    failedRecords.add(BufferedLogRecord(
      record: record,
      retryCount: 1,
      firstAttempt: DateTime.now(),
    ));
    await _saveFailedLogRecords(failedRecords);
  }

  static Future<void> handleRetryFailedLogRecord(LogRecord record) async {
    final failedRecords = await loadFailedLogRecords();
    
    final existingIndex = failedRecords.indexWhere((buffered) => 
        buffered.record.eventType == record.eventType && 
        buffered.record.deviceId == record.deviceId &&
        buffered.record.model == record.model);
    
    final bufferedRecord = failedRecords[existingIndex];
    bufferedRecord.retryCount++;
    
    if (bufferedRecord.retryCount > _maxRetries) {
      failedRecords.removeAt(existingIndex);
    } else {
      debugPrint('Retry ${bufferedRecord.retryCount}/$_maxRetries for buffered log record');
    }
    await _saveFailedLogRecords(failedRecords);
  }

  static Future<void> _saveFailedLogRecords(List<BufferedLogRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(records.map((record) => record.toJson()).toList());
      await prefs.setString(_failedLogRecordsKey, jsonString);
    } catch (e) {
      debugPrint('Error saving failed log records: $e');
    }
  }
}