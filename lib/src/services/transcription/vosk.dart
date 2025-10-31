import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:cactus/src/services/bindings.dart';
import 'package:cactus/src/models/binding.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/utils/speech/speech_utils.dart';
import 'package:record/record.dart';

Future<Map<String, dynamic>> _initializeVoskInIsolate(Map<String, dynamic> params) async {
  final modelFolder = params['modelFolder'] as String;
  final spkModelFolder = params['spkModelFolder'] as String;

  try {
    final modelNew = voskModelNew;
    final spkModelNew = voskSpkModelNew;
    
    if (modelNew == null || spkModelNew == null) {
      return {'success': false, 'error': 'Vosk functions not available'};
    }

    final modelPathPtr = modelFolder.toNativeUtf8();
    final spkModelPathPtr = spkModelFolder.toNativeUtf8();
    
    try {
      final model = modelNew(modelPathPtr);
      final spkModel = spkModelNew(spkModelPathPtr);
      
      final initialized = (model != nullptr && spkModel != nullptr);
      return {
        'success': initialized,
        'modelAddress': initialized ? model.address : null,
        'spkModelAddress': initialized ? spkModel.address : null,
      };
    } finally {
      malloc.free(modelPathPtr);
      malloc.free(spkModelPathPtr);
    }
  } catch (e) {
    return {'success': false, 'error': 'Error initializing speech recognition: $e'};
  }
}

Future<Map<String, dynamic>> _recognizeFileInIsolate(Map<String, dynamic> params) async {
  final modelAddress = params['modelAddress'] as int;
  final spkModelAddress = params['spkModelAddress'] as int;
  final filePath = params['filePath'] as String;
  final sampleRate = params['sampleRate'] as int;

  try {
    final model = Pointer<VoskModelOpaque>.fromAddress(modelAddress);
    final spkModel = Pointer<VoskSpkModelOpaque>.fromAddress(spkModelAddress);
    
    final recognizerNew = voskRecognizerNewSpk;
    if (recognizerNew == null) {
      return {'success': false, 'error': 'Speech recognizer not available'};
    }

    final recognizer = recognizerNew(model, sampleRate.toDouble(), spkModel);
    if (recognizer == nullptr) {
      return {'success': false, 'error': 'Failed to create speech recognizer'};
    }

    try {
      if (!await File(filePath).exists()) {
        return {'success': false, 'error': 'Audio file not found: $filePath'};
      }

      final audioData = await File(filePath).readAsBytes();
      final startTime = DateTime.now();

      final acceptWaveform = voskRecognizerAcceptWaveform;
      final getResult = voskRecognizerResult;
      final getFinalResult = voskRecognizerFinalResult;

      if (acceptWaveform == null || getResult == null || getFinalResult == null) {
        return {'success': false, 'error': 'Speech recognition functions not available'};
      }

      String? finalResult;

      // Process audio data in chunks
      const chunkSize = 4096;
      for (int i = 0; i < audioData.length; i += chunkSize) {
        final end = (i + chunkSize < audioData.length) ? i + chunkSize : audioData.length;
        final chunk = audioData.sublist(i, end);

        final chunkPtr = malloc<Uint8>(chunk.length);
        try {
          for (int j = 0; j < chunk.length; j++) {
            chunkPtr[j] = chunk[j];
          }

          if (acceptWaveform(recognizer, chunkPtr, chunk.length)) {
            final resultPtr = getResult(recognizer);
            if (resultPtr != nullptr) {
              final resultText = resultPtr.toDartString();
              try {
                final json = jsonDecode(resultText) as Map<String, dynamic>;
                final text = json['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  finalResult = text;
                  break;
                }
              } catch (e) {
                // Ignore JSON parsing errors
              }
            }
          }
        } finally {
          malloc.free(chunkPtr);
        }
      }

      if (finalResult == null) {
        final finalResultPtr = getFinalResult(recognizer);
        if (finalResultPtr != nullptr) {
          final resultText = finalResultPtr.toDartString();
          try {
            final json = jsonDecode(resultText) as Map<String, dynamic>;
            final text = json['text'] as String?;
            if (text != null && text.isNotEmpty) {
              finalResult = text;
            }
          } catch (e) {
            // Ignore JSON parsing errors
          }
        }
      }

      final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

      return {
        'success': true,
        'text': finalResult?.trim() ?? "",
        'processingTime': processingTime,
      };

    } finally {
      final recognizerFree = voskRecognizerFree;
      recognizerFree?.call(recognizer);
    }
  } catch (e) {
    return {'success': false, 'error': 'Error during speech recognition: $e'};
  }
}

class VoskService with SpeechServiceStateMixin {
  static VoskModel? _model;
  static VoskSpkModel? _spkModel;

  static final VoskService _instance = VoskService._internal();
  VoskService._internal();

  static Future<bool> initialize(String modelFolder, String spkModelFolder) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await compute(_initializeVoskInIsolate, {
        'modelFolder': modelFolder,
        'spkModelFolder': spkModelFolder,
      });

      if (result['success'] == true) {
        final modelAddress = result['modelAddress'] as int;
        final spkModelAddress = result['spkModelAddress'] as int;
        
        _model = Pointer<VoskModelOpaque>.fromAddress(modelAddress);
        _spkModel = Pointer<VoskSpkModelOpaque>.fromAddress(spkModelAddress);
        
        _instance.setInitialized(true);
        return true;
      } else {
        debugPrint(result['error'] ?? 'Unknown initialization error');
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      return false;
    }
  }

  static Future<SpeechRecognitionResult?> recognize({
    required SpeechRecognitionParams params,
    String? filePath,
  }) async {
    if (!_instance.isInitialized || _model == null || _spkModel == null) {
      return SpeechUtils.createErrorResult("Speech recognition not initialized");
    }

    if (!Platform.isAndroid) {
      return SpeechUtils.createErrorResult("Speech recognition only available on Android");
    }

    if (!SpeechUtils.validateSpeechParams(params)) {
      return SpeechUtils.createErrorResult("Invalid speech recognition parameters");
    }

    try {
      final recognizerNew = voskRecognizerNewSpk;
      if (recognizerNew == null) {
        return SpeechUtils.createErrorResult("Speech recognizer not available");
      }

      final recognizer = recognizerNew(_model!, params.sampleRate.toDouble(), _spkModel!);
      if (recognizer == nullptr) {
        return SpeechUtils.createErrorResult("Failed to create speech recognizer");
      }

      try {
        if (filePath != null) {
          return await _recognizeFromFile(recognizer, filePath, params);
        } else {
          return await _recognizeFromMicrophone(recognizer, params);
        }
      } finally {
        final recognizerFree = voskRecognizerFree;
        recognizerFree?.call(recognizer);
      }
    } catch (e) {
      return SpeechUtils.createErrorResult("Error during speech recognition: $e");
    }
  }

  static void stop() {
    _instance.stopRecording();
  }

  static bool get isCurrentlyRecording => _instance.isRecording;

  static bool get isServiceReady => _instance.isReady && _model != null && _spkModel != null;

  static void dispose() {
    if (_model != null) {
      final modelFree = voskModelFree;
      modelFree?.call(_model!);
      _model = null;
    }
    
    if (_spkModel != null) {
      final spkModelFree = voskSpkModelFree;
      spkModelFree?.call(_spkModel!);
      _spkModel = null;
    }
    
    _instance.disposeResources();
  }

  static Future<SpeechRecognitionResult?> _recognizeFromFile(
    VoskRecognizer recognizer,
    String filePath,
    SpeechRecognitionParams params,
  ) async {
    try {
      if (_model == null || _spkModel == null) {
        return SpeechUtils.createErrorResult("Speech recognition not initialized");
      }

      final result = await compute(_recognizeFileInIsolate, {
        'modelAddress': _model!.address,
        'spkModelAddress': _spkModel!.address,
        'filePath': filePath,
        'sampleRate': params.sampleRate,
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
    VoskRecognizer recognizer,
    SpeechRecognitionParams params,
  ) async {
    try {
      // Check microphone permission
      if (!await SpeechUtils.ensureMicrophonePermission()) {
        return SpeechUtils.createErrorResult("Microphone permission denied");
      }

      // Check if already recording
      if (_instance.isRecording) {
        return SpeechUtils.createErrorResult("Already recording");
      }

      _instance.setRecording(true);
      final startTime = DateTime.now();
      final recordingStartTime = DateTime.now().millisecondsSinceEpoch;

      String? finalResult;
      String lastPartialResult = "";
      int silenceStartTime = 0;
      bool hasDetectedSpeech = false;

      try {
        final acceptWaveform = voskRecognizerAcceptWaveform;
        final getResult = voskRecognizerResult;
        final getPartialResult = voskRecognizerPartialResult;
        final getFinalResult = voskRecognizerFinalResult;

        if (acceptWaveform == null || getResult == null || getFinalResult == null) {
          _instance.setRecording(false);
          return SpeechUtils.createErrorResult("Speech recognition functions not available");
        }

        // Configure recording for streaming
        final config = SpeechUtils.createRecordingConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        );

        // Start streaming audio
        final audioStream = await _instance.audioRecorder.startStream(config);
        
        // Process audio stream in real-time (similar to Kotlin implementation)
        await for (final audioChunk in audioStream) {
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          
          // Check for maximum duration timeout
          if (currentTime - recordingStartTime > params.maxDuration) {
            debugPrint("Maximum recording duration reached");
            break;
          }

          // Check for manual stop
          if (!_instance.isRecording) {
            break;
          }

          // Calculate audio level for voice activity detection
          double audioLevel = 0.0;
          for (int i = 0; i < audioChunk.length; i += 2) {
            if (i + 1 < audioChunk.length) {
              // Convert bytes to 16-bit sample
              final sample = (audioChunk[i + 1] << 8) | audioChunk[i];
              final signedSample = sample > 32767 ? sample - 65536 : sample;
              audioLevel += signedSample.abs().toDouble();
            }
          }
          audioLevel /= (audioChunk.length / 2);
          final hasVoiceActivity = audioLevel > 500.0;

          // Allocate memory for the audio chunk
          final chunkPtr = malloc<Uint8>(audioChunk.length);
          try {
            // Copy audio data to native memory
            for (int i = 0; i < audioChunk.length; i++) {
              chunkPtr[i] = audioChunk[i];
            }

            // Process audio chunk with Vosk
            if (acceptWaveform(recognizer, chunkPtr, audioChunk.length)) {
              // Handle final results
              final resultPtr = getResult(recognizer);
              if (resultPtr != nullptr) {
                final resultText = resultPtr.toDartString();
                try {
                  final json = jsonDecode(resultText) as Map<String, dynamic>;
                  final text = json['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    finalResult = text;
                    hasDetectedSpeech = true;
                    silenceStartTime = 0;
                    break;
                  }
                } catch (e) {
                  // Ignore JSON parsing errors
                }
              }
            }

            if (getPartialResult != null) {
              final partialPtr = getPartialResult(recognizer);
              if (partialPtr != nullptr) {
                final partialText = partialPtr.toDartString();
                try {
                  final json = jsonDecode(partialText) as Map<String, dynamic>;
                  final partial = json['partial'] as String?;
                  if (partial != null && partial.isNotEmpty && partial != lastPartialResult) {
                    lastPartialResult = partial;
                    hasDetectedSpeech = true;
                    silenceStartTime = 0;
                  }
                } catch (e) {
                  // Ignore JSON parsing errors
                }
              }
            }

            if (hasVoiceActivity) {
              silenceStartTime = 0;
            } else {
              if (hasDetectedSpeech) {
                if (silenceStartTime == 0) {
                  silenceStartTime = currentTime;
                } else if (currentTime - silenceStartTime > params.maxSilenceDuration) {
                  debugPrint("Silence timeout reached after detecting speech");
                  break;
                }
              }
            }

          } finally {
            malloc.free(chunkPtr);
          }
        }

        await _instance.audioRecorder.stop();
        _instance.setRecording(false);

        if (finalResult == null) {
          final finalResultPtr = getFinalResult(recognizer);
          if (finalResultPtr != nullptr) {
            final resultText = finalResultPtr.toDartString();
            try {
              final json = jsonDecode(resultText) as Map<String, dynamic>;
              final text = json['text'] as String?;
              if (text != null && text.isNotEmpty) {
                finalResult = text;
              }
            } catch (e) {
              // Ignore JSON parsing errors
            }
          }
        }

        if (finalResult == null && lastPartialResult.isNotEmpty) {
          finalResult = lastPartialResult;
        }

        final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

        return SpeechUtils.createSuccessResult(
          finalResult?.trim() ?? "",
          processingTime: processingTime,
        );

      } catch (e) {
        _instance.setRecording(false);
        try {
          await _instance.audioRecorder.stop();
        } catch (_) {}
        return SpeechUtils.createErrorResult("Recording error: $e");
      }

    } catch (e) {
      _instance.setRecording(false);
      return SpeechUtils.createErrorResult("Microphone recording failed: $e");
    }
  }
}