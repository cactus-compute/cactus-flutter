import 'dart:async';
import 'dart:io';
import 'dart:math';

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

class PCMUtils {
  static const int whisperSampleRate = 16000;
  static const int bytesPerSample = 2;

  static bool validatePCMBuffer(List<int> pcmData) {
    return pcmData.length % bytesPerSample == 0;
  }
  
  static double calculateDuration(List<int> pcmData, {int sampleRate = whisperSampleRate}) {
    final numSamples = pcmData.length ~/ bytesPerSample;
    return numSamples / sampleRate;
  }
  
  static int getSampleCount(List<int> pcmData) {
    return pcmData.length ~/ bytesPerSample;
  }
  
  static List<int> generateSyntheticAudio({
    required int durationSeconds,
    double frequency = 440.0,
    double amplitude = 0.3,
    int sampleRate = whisperSampleRate,
  }) {
    final numSamples = sampleRate * durationSeconds;
    final pcmBytes = <int>[];
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final value = amplitude * sin(2.0 * pi * frequency * t);
      
      final sample = (value * 32767.0).round().clamp(-32768, 32767);
      
      pcmBytes.add(sample & 0xFF);
      pcmBytes.add((sample >> 8) & 0xFF);
    }
    
    return pcmBytes;
  }
  
  static Float32List pcmToFloat32(List<int> pcmData) {
    final numSamples = pcmData.length ~/ bytesPerSample;
    final samples = Float32List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final byteIndex = i * bytesPerSample;
      final sample = (pcmData[byteIndex] | (pcmData[byteIndex + 1] << 8));
      samples[i] = (sample < 32768 ? sample : sample - 65536) / 32768.0;
    }
    
    return samples;
  }

  static List<int> float32ToPCM(Float32List samples) {
    final pcmBytes = <int>[];
    
    for (int i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final sample = (clamped * 32767.0).round().clamp(-32768, 32767);
      
      pcmBytes.add(sample & 0xFF);
      pcmBytes.add((sample >> 8) & 0xFF);
    }
    
    return pcmBytes;
  }

  static List<int> trimToValidSamples(List<int> pcmData) {
    if (pcmData.length % bytesPerSample == 0) {
      return pcmData;
    }
    return pcmData.sublist(0, pcmData.length - 1);
  }

  static RecordConfig createWhisperRecordConfig() {
    return const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: whisperSampleRate,
      numChannels: 1, // Mono
    );
  }
}