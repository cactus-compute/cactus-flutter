import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:cactus/src/services/bindings.dart';
import 'package:cactus/src/models/binding.dart';
import 'package:cactus/models/types.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechRecognitionService {
  static VoskModel? _model;
  static VoskSpkModel? _spkModel;
  static bool _isInitialized = false;
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static bool _isRecording = false;

  static Future<bool> initialize(String modelFolder, String spkModelFolder) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final modelNew = voskModelNew;
      final spkModelNew = voskSpkModelNew;
      
      if (modelNew == null || spkModelNew == null) {
        return false;
      }

      final modelPathPtr = modelFolder.toNativeUtf8();
      final spkModelPathPtr = spkModelFolder.toNativeUtf8();
      
      try {
        _model = modelNew(modelPathPtr);
        _spkModel = spkModelNew(spkModelPathPtr);
        
        _isInitialized = (_model != nullptr && _spkModel != nullptr);
        return _isInitialized;
      } finally {
        malloc.free(modelPathPtr);
        malloc.free(spkModelPathPtr);
      }
    } catch (e) {
      print('Error initializing speech recognition: $e');
      return false;
    }
  }

  static Future<SpeechRecognitionResult?> recognize({
    required SpeechRecognitionParams params,
    String? filePath,
  }) async {
    if (!_isInitialized || _model == null || _spkModel == null) {
      return SpeechRecognitionResult(
        success: false,
        text: "Speech recognition not initialized",
      );
    }

    if (!Platform.isAndroid) {
      return SpeechRecognitionResult(
        success: false,
        text: "Speech recognition only available on Android",
      );
    }

    try {
      final recognizerNew = voskRecognizerNewSpk;
      if (recognizerNew == null) {
        return SpeechRecognitionResult(
          success: false,
          text: "Speech recognizer not available",
        );
      }

      final recognizer = recognizerNew(_model!, params.sampleRate.toDouble(), _spkModel!);
      if (recognizer == nullptr) {
        return SpeechRecognitionResult(
          success: false,
          text: "Failed to create speech recognizer",
        );
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

  static bool get isReady => _isInitialized && _model != null && _spkModel != null;

  /// Clean up resources
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
    
    _isInitialized = false;
  }

  static Future<SpeechRecognitionResult?> _recognizeFromFile(
    VoskRecognizer recognizer,
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

      final audioData = await file.readAsBytes();
      final startTime = DateTime.now();

      final acceptWaveform = voskRecognizerAcceptWaveform;
      final getResult = voskRecognizerResult;
      final getFinalResult = voskRecognizerFinalResult;

      if (acceptWaveform == null || getResult == null || getFinalResult == null) {
        return SpeechRecognitionResult(
          success: false,
          text: "Speech recognition functions not available",
        );
      }

      // Process audio data in chunks
      var offset = 0;
      const chunkSize = 4000;
      var finalResult = "";

      while (offset < audioData.length) {
        final remainingBytes = audioData.length - offset;
        final currentChunkSize = remainingBytes < chunkSize ? remainingBytes : chunkSize;
        
        // Allocate memory for the chunk
        final chunkPtr = malloc<Uint8>(currentChunkSize);
        try {
          // Copy chunk data to native memory
          for (int i = 0; i < currentChunkSize; i++) {
            chunkPtr[i] = audioData[offset + i];
          }

          if (acceptWaveform(recognizer, chunkPtr, currentChunkSize)) {
            final resultPtr = getResult(recognizer);
            if (resultPtr != nullptr) {
              final resultText = resultPtr.toDartString();
              try {
                final json = jsonDecode(resultText) as Map<String, dynamic>;
                final text = json['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  finalResult = finalResult.isEmpty ? text : "$finalResult $text";
                }
              } catch (e) {
                // Ignore JSON parsing errors
              }
            }
          }
        } finally {
          malloc.free(chunkPtr);
        }
        
        offset += currentChunkSize;
      }

      // Get final result
      final finalResultPtr = getFinalResult(recognizer);
      if (finalResultPtr != nullptr) {
        final resultText = finalResultPtr.toDartString();
        try {
          final json = jsonDecode(resultText) as Map<String, dynamic>;
          final text = json['text'] as String?;
          if (text != null && text.isNotEmpty) {
            finalResult = finalResult.isEmpty ? text : "$finalResult $text";
          }
        } catch (e) {
          // Ignore JSON parsing errors
        }
      }

      final processingTime = DateTime.now().difference(startTime).inMilliseconds.toDouble();

      return SpeechRecognitionResult(
        success: finalResult.isNotEmpty,
        text: finalResult.isNotEmpty ? finalResult.trim() : "No speech detected in audio file",
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
    VoskRecognizer recognizer,
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
          _isRecording = false;
          return SpeechRecognitionResult(
            success: false,
            text: "Speech recognition functions not available",
          );
        }

        // Configure recording for streaming
        const config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        );

        // Start streaming audio
        final audioStream = await _audioRecorder.startStream(config);
        
        // Process audio stream in real-time (similar to Kotlin implementation)
        await for (final audioChunk in audioStream) {
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          
          // Check for maximum duration timeout
          if (currentTime - recordingStartTime > params.maxDuration) {
            print("Maximum recording duration reached");
            break;
          }

          // Check for manual stop
          if (!_isRecording) {
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
                  print("Silence timeout reached after detecting speech");
                  break;
                }
              }
            }

          } finally {
            malloc.free(chunkPtr);
          }
        }

        await _audioRecorder.stop();
        _isRecording = false;

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

        return SpeechRecognitionResult(
          success: finalResult != null && finalResult.isNotEmpty,
          text: finalResult?.trim() ?? "No speech detected",
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