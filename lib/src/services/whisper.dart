import 'dart:async';
import 'dart:ffi';

import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/bindings.dart';
import 'package:cactus/src/models/binding.dart';
import 'package:cactus/src/utils/speech_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> _initializeWhisperInIsolate(Map<String, dynamic> params) async {
  final modelPath = params['modelPath'] as String;

  try {
    if (!await SpeechUtils.fileExists(modelPath)) {
      return {'success': false, 'error': 'Whisper model file not found: $modelPath'};
    }

    final modelPathPtr = modelPath.toNativeUtf8();
    try {
      final context = whisperInitFromFile(modelPathPtr);
      
      if (context == nullptr) {
        return {'success': false, 'error': 'Failed to initialize whisper context from model: $modelPath'};
      }

      return {
        'success': true,
        'contextAddress': context.address,
        'modelPath': modelPath,
      };
    } finally {
      malloc.free(modelPathPtr);
    }
  } catch (e) {
    return {'success': false, 'error': 'Error initializing Whisper: $e'};
  }
}

Future<Map<String, dynamic>> _recognizeFileInIsolate(Map<String, dynamic> params) async {
  final contextAddress = params['contextAddress'] as int;
  final filePath = params['filePath'] as String;

  try {
    final context = Pointer<WhisperContextOpaque>.fromAddress(contextAddress);
    
    if (!await SpeechUtils.fileExists(filePath)) {
      return {'success': false, 'error': 'Audio file not found: $filePath'};
    }

    final startTime = DateTime.now();
    final audioData = await SpeechUtils.readWavFile(filePath);
    if (audioData == null) {
      return {'success': false, 'error': 'Failed to read audio file'};
    }

    final paramsPtr = whisperFullDefaultParamsByRef(WhisperSamplingStrategy.whisperSamplingGreedy);
    if (paramsPtr == nullptr) {
      return {'success': false, 'error': 'Failed to get whisper parameters'};
    }

    final audioPtr = malloc<Float>(audioData.length);
    try {
      for (int i = 0; i < audioData.length; i++) {
        audioPtr[i] = audioData[i];
      }

      final result = whisperFull(context, paramsPtr, audioPtr, audioData.length);
      
      if (result != 0) {
        return {'success': false, 'error': 'Whisper processing failed with code: $result'};
      }

      final nSegments = whisperFullNSegments(context);
      final StringBuffer textBuffer = StringBuffer();
      
      for (int i = 0; i < nSegments; i++) {
        final segmentTextPtr = whisperFullGetSegmentText(context, i);
        if (segmentTextPtr != nullptr) {
          final segmentText = segmentTextPtr.cast<Utf8>().toDartString();
          textBuffer.write(segmentText);
        }
      }

      final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();
      final text = textBuffer.toString().trim();

      return {
        'success': true,
        'text': text,
        'processingTime': processingTime,
      };

    } finally {
      malloc.free(audioPtr);
      whisperFreeParams(paramsPtr);
    }
  } catch (e) {
    return {'success': false, 'error': 'Error processing audio file: $e'};
  }
}

class WhisperService with SpeechServiceStateMixin {
  static WhisperContext? _context;
  static String? _currentModelPath;

  static Future<bool> initialize({
    required String modelPath,
  }) async {
    try {
      // Run heavy initialization in isolate
      final result = await compute(_initializeWhisperInIsolate, {
        'modelPath': modelPath,
      });

      if (result['success'] == true) {
        // Store the context address for later use
        final contextAddress = result['contextAddress'] as int;
        _context = Pointer<WhisperContextOpaque>.fromAddress(contextAddress);
        _currentModelPath = result['modelPath'] as String;
        
        _instance.setInitialized(true);
        print('Whisper initialized successfully with model: $_currentModelPath');
        return true;
      } else {
        print(result['error'] ?? 'Unknown initialization error');
        return false;
      }
    } catch (e) {
      print('Error initializing Whisper: $e');
      return false;
    }
  }

  static final WhisperService _instance = WhisperService._internal();
  WhisperService._internal();

  static Future<SpeechRecognitionResult?> recognize({
    required SpeechRecognitionParams params,
    String? filePath,
  }) async {
    if (!_instance.isInitialized || _context == null) {
      return SpeechUtils.createErrorResult("Whisper not initialized");
    }

    if (!SpeechUtils.validateSpeechParams(params)) {
      return SpeechUtils.createErrorResult("Invalid speech recognition parameters");
    }

    try {
      if (filePath != null) {
        return await _recognizeFromFile(filePath, params);
      } else {
        return await _recognizeFromMicrophone(params);
      }
    } catch (e) {
      return SpeechUtils.createErrorResult("Error during speech recognition: $e");
    }
  }

  static Future<SpeechRecognitionResult?> _recognizeFromFile(
    String filePath,
    SpeechRecognitionParams params,
  ) async {
    try {
      if (_context == null) {
        return SpeechUtils.createErrorResult("Whisper not initialized");
      }

      final result = await compute(_recognizeFileInIsolate, {
        'contextAddress': _context!.address,
        'filePath': filePath,
      });

      if (result['success'] == true) {
        return SpeechUtils.createSuccessResult(
          result['text'] as String,
          processingTime: result['processingTime'] as double?,
        );
      } else {
        return SpeechUtils.createErrorResult(
          result['error'] as String? ?? 'Unknown error during file recognition'
        );
      }
    } catch (e) {
      return SpeechUtils.createErrorResult("Error processing audio file: $e");
    }
  }

  static Future<SpeechRecognitionResult?> _recognizeFromMicrophone(
    SpeechRecognitionParams params,
  ) async {
    try {
      if (!await SpeechUtils.ensureMicrophonePermission()) {
        return SpeechUtils.createErrorResult("Microphone permission denied");
      }

      if (_instance.isRecording) {
        return SpeechUtils.createErrorResult("Already recording");
      }

      try {
        final config = SpeechUtils.createRecordingConfig(
          sampleRate: 16000,
          numChannels: 1,
        );

        final tempFilePath = SpeechUtils.createTempRecordingPath();

        if (!await _instance.startRecording(config, tempFilePath)) {
          return SpeechUtils.createErrorResult("Failed to start recording");
        }

        await Future.delayed(Duration(milliseconds: params.maxDuration));

        await _instance.stopRecording();

        if (!await SpeechUtils.fileExists(tempFilePath)) {
          return SpeechUtils.createErrorResult("Recording file not created");
        }

        final result = await _recognizeFromFile(tempFilePath, params);

        await SpeechUtils.cleanupTempFile(tempFilePath);

        return result;

      } catch (e) {
        await _instance.stopRecording();
        return SpeechUtils.createErrorResult("Recording error: $e");
      }

    } catch (e) {
      return SpeechUtils.createErrorResult("Microphone recording failed: $e");
    }
  }

  static void stop() {
    _instance.stopRecording();
  }

  static bool get isCurrentlyRecording => _instance.isRecording;

  static bool get isServiceReady => _instance.isReady && _context != null;

  static void dispose() {
    if (_context != null) {
      whisperFree(_context!);
      _context = null;
    }
    _instance.disposeResources();
    _currentModelPath = null;
  }
}