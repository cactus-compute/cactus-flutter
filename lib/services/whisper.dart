import 'dart:async';
import 'dart:io';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'package:cactus/models/types.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class WhisperService {
  static Whisper? _whisper;
  static bool _isInitialized = false;
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static bool _isRecording = false;

  static Future<bool> initialize({required WhisperModel model}) async {
    try {
      _whisper = Whisper(
        model: model,
        downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
      );

      // Get version to verify initialization
      final version = await _whisper!.getVersion();
      _isInitialized = version != null;

      if (_isInitialized) {
        print('Whisper initialized successfully. Version: $version');
      } else {
        print('Failed to initialize Whisper');
      }

      return _isInitialized;
    } catch (e) {
      print('Error initializing Whisper: $e');
      return false;
    }
  }

  static Future<SpeechRecognitionResult?> recognize({
    required SpeechRecognitionParams params,
    String? filePath,
  }) async {
    if (!_isInitialized || _whisper == null) {
      return SpeechRecognitionResult(
        success: false,
        text: "Whisper not initialized",
      );
    }

    try {
      if (filePath != null) {
        return await _recognizeFromFile(filePath, params);
      } else {
        return await _recognizeFromMicrophone(params);
      }
    } catch (e) {
      return SpeechRecognitionResult(
        success: false,
        text: "Error during speech recognition: $e",
      );
    }
  }

  static void stop() {
    _isRecording = false;
    _audioRecorder.stop();
  }

  static bool get isRecording => _isRecording;

  static bool get isReady => _isInitialized && _whisper != null;

  /// Clean up resources
  static void dispose() {
    _whisper = null;
    _isInitialized = false;
  }

  static Future<SpeechRecognitionResult?> _recognizeFromFile(
    String filePath,
    SpeechRecognitionParams params,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return SpeechRecognitionResult(
          success: false,
          text: "Audio file not found: $filePath",
        );
      }

      final startTime = DateTime.now();

      // Use whisper_flutter_new to transcribe the audio file
      final transcription = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: filePath,
          isTranslate: false, // Keep original language unless translation is needed
          isNoTimestamps: true, // No timestamps for simple transcription
          splitOnWord: true, // Split segments on each word
        ),
      );

      final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

      // Extract text from transcription response
      final text = transcription.text;

      return SpeechRecognitionResult(
        success: text.isNotEmpty,
        text: text.isNotEmpty ? text : "No speech detected in audio file",
        processingTime: processingTime,
      );
    } catch (e) {
      return SpeechRecognitionResult(
        success: false,
        text: "Error processing audio file: $e",
      );
    }
  }

  static Future<SpeechRecognitionResult?> _recognizeFromMicrophone(
    SpeechRecognitionParams params,
  ) async {
    try {
      // Check microphone permission
      if (!await _hasMicrophonePermission()) {
        final granted = await _requestMicrophonePermission();
        if (!granted) {
          return SpeechRecognitionResult(
            success: false,
            text: "Microphone permission denied",
          );
        }
      }

      // Check if already recording
      if (_isRecording) {
        return SpeechRecognitionResult(
          success: false,
          text: "Already recording",
        );
      }

      _isRecording = true;
      final startTime = DateTime.now();

      try {
        // Configure recording - record to a temporary file
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        // Create a temporary file path
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.wav');

        // Start recording to file
        await _audioRecorder.start(config, path: tempFile.path);

        // Wait for the recording duration or until stopped
        await Future.delayed(Duration(milliseconds: params.maxDuration));

        // Stop recording
        await _audioRecorder.stop();
        _isRecording = false;

        // Check if file exists and has content
        if (!await tempFile.exists()) {
          return SpeechRecognitionResult(
            success: false,
            text: "Recording file not created",
          );
        }

        // Transcribe the recorded file
        final transcription = await _whisper!.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: tempFile.path,
            isTranslate: false,
            isNoTimestamps: true,
            splitOnWord: true,
          ),
        );

        // Clean up temporary file
        try {
          await tempFile.delete();
        } catch (_) {
          // Ignore cleanup errors
        }

        final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

        // Extract text from transcription response
        final text = transcription.text;

        return SpeechRecognitionResult(
          success: text.isNotEmpty,
          text: text.isNotEmpty ? text : "No speech detected",
          processingTime: processingTime,
        );

      } catch (e) {
        _isRecording = false;
        try {
          await _audioRecorder.stop();
        } catch (_) {}
        return SpeechRecognitionResult(
          success: false,
          text: "Recording error: $e",
        );
      }

    } catch (e) {
      _isRecording = false;
      return SpeechRecognitionResult(
        success: false,
        text: "Microphone recording failed: $e",
      );
    }
  }

  static Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> _hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }
}
