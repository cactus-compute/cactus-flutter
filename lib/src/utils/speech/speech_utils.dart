import 'dart:async';
import 'dart:io';

import 'package:cactus/models/types.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class SpeechUtils {
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> ensureMicrophonePermission() async {
    if (!await hasMicrophonePermission()) {
      return await requestMicrophonePermission();
    }
    return true;
  }

  static SpeechRecognitionResult createErrorResult(String message) {
    return SpeechRecognitionResult(
      success: false,
      text: message,
    );
  }

  static SpeechRecognitionResult createSuccessResult(
    String text, {
    double? processingTime,
  }) {
    return SpeechRecognitionResult(
      success: text.isNotEmpty,
      text: text.isNotEmpty ? text : "No speech detected",
      processingTime: processingTime,
    );
  }

  static Future<Float32List?> readWavFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      if (bytes.length < 44) return null;
      
      final pcmData = bytes.sublist(44);
      final samples = Float32List(pcmData.length ~/ 2);
      
      for (int i = 0; i < samples.length; i++) {
        final sample = (pcmData[i * 2] | (pcmData[i * 2 + 1] << 8));
        samples[i] = (sample < 32768 ? sample : sample - 65536) / 32768.0;
      }
      
      return samples;
    } catch (e) {
      debugPrint('Error reading WAV file: $e');
      return null;
    }
  }

  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  static String createTempRecordingPath() {
    final tempDir = Directory.systemTemp;
    return '${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  static Future<void> cleanupTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Warning: Failed to cleanup temp file $filePath: $e');
    }
  }

  static RecordConfig createRecordingConfig({
    int sampleRate = 16000,
    int numChannels = 1,
    AudioEncoder encoder = AudioEncoder.wav,
  }) {
    return RecordConfig(
      encoder: encoder,
      sampleRate: sampleRate,
      numChannels: numChannels,
    );
  }

  static bool validateSpeechParams(SpeechRecognitionParams params) {
    return params.maxDuration > 0 &&
           params.sampleRate > 0;
  }
}

mixin SpeechServiceStateMixin {
  bool _isInitialized = false;
  bool _isRecording = false;
  late final AudioRecorder _audioRecorder = AudioRecorder();

  bool get isInitialized => _isInitialized;

  bool get isRecording => _isRecording;

  bool get isReady => _isInitialized;

  void setInitialized(bool initialized) {
    _isInitialized = initialized;
  }

  void setRecording(bool recording) {
    _isRecording = recording;
  }

  AudioRecorder get audioRecorder => _audioRecorder;

  Future<void> stopRecording() async {
    if (_isRecording) {
      _isRecording = false;
      try {
        await _audioRecorder.stop();
      } catch (e) {
        debugPrint('Warning: Error stopping audio recorder: $e');
      }
    }
  }

  Future<bool> startRecording(RecordConfig config, String filePath) async {
    try {
      if (_isRecording) {
        return false;
      }

      await _audioRecorder.start(config, path: filePath);
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  void disposeResources() {
    _isInitialized = false;
    _isRecording = false;
  }
}