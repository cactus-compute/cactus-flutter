import 'dart:async';

import 'package:cactus/models/types.dart';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/context.dart';
import 'package:cactus/src/utils/models/download.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:cactus/src/services/api/telemetry.dart';
import 'package:cactus/src/utils/speech/speech_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CactusSTT {
  int? _handle;
  String? _lastInitializedModel;
  static const String whisperPrompt = '<|startoftranscript|><|en|><|transcribe|><|notimestamps|>';
  CactusInitParams defaultInitParams = CactusInitParams();
  CactusTranscriptionParams defaultTranscriptionParams = CactusTranscriptionParams();
  final List<VoiceModel> _models = [];
  int chunkDurationSec = 5;

  final _handleLock = _AsyncLock();

  Future<void> downloadModel({
    required String model,
    final CactusProgressCallback? downloadProcessCallback,
  }) async {
    if (await _isModelDownloaded(model)) {
      return;
    }

    final voiceModels = await Supabase.fetchVoiceModels();
    final currentModel = voiceModels.firstWhere(
      (m) => m.slug == model,
      orElse: () => throw Exception('Voice model $model not found'),
    );

    final task = DownloadTask(
      url: currentModel.downloadUrl,
      filename: currentModel.fileName,
      folder: currentModel.slug,
    );

    final success = await DownloadService.downloadAndExtractModels([task], downloadProcessCallback);
    if (!success) {
      throw Exception('Failed to download and extract voice model $model from ${currentModel.downloadUrl}');
    }
  }

  Future<void> initializeModel({final CactusInitParams? params}) async {
    if (!Telemetry.isInitialized) {
      await Telemetry.init(CactusTelemetry.telemetryToken);
    }

    final model = params?.model ?? _lastInitializedModel ?? defaultInitParams.model;
    final modelPath = '${(await getApplicationDocumentsDirectory()).path}/models/$model';

    final result = await CactusContext.initContext(modelPath, ((params?.contextSize) ?? defaultInitParams.contextSize)!);
    _handle = result.$1;

    if (_handle == null && !await _isModelDownloaded(model)) {
      debugPrint('Failed to initialize model context with model at $modelPath, trying to download the model first.');
      await downloadModel(model: model);
      return initializeModel(params: params);
    }

    if (Telemetry.isInitialized) {
      Telemetry.instance?.logInit(_handle != null, model, result.$2);
    }

    if (_handle == null) {
      throw Exception('Failed to initialize model context with model at $modelPath');
    }
    _lastInitializedModel = model;
  }

  Future<CactusTranscriptionResult> transcribe({
    String? audioFilePath,
    Stream<Uint8List>? audioStream,
    Function(CactusTranscriptionResult)? onChunk,
    String prompt = whisperPrompt,
    CactusTranscriptionParams? params,
  }) async {
    if (audioFilePath == null && audioStream == null) {
      throw ArgumentError('Must provide either audioFilePath or audioStream');
    }
    
    if (audioFilePath != null && audioStream != null) {
      throw ArgumentError('Cannot provide both audioFilePath and audioStream');
    }

    // File transcription mode
    if (audioFilePath != null) {
      return await _handleLock.synchronized(() async {
        final transcriptionParams = params ?? defaultTranscriptionParams;
        final model = _lastInitializedModel ?? defaultInitParams.model;
        final currentHandle = await _getValidatedHandle(model: model);

        if (currentHandle != null) {
          try {
            final result = await CactusContext.transcribe(
              currentHandle,
              audioFilePath,
              prompt,
              params: transcriptionParams,
            );
            _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
            return result;
          } catch (e) {
            debugPrint('Transcription failed: $e');
            _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
            rethrow;
          }
        }

        throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
      });
    }

    final List<int> buffer = [];
    final completer = Completer<CactusTranscriptionResult>();
    CactusTranscriptionResult? combinedResult;

    final subscription = audioStream!.listen(
      (pcmChunk) async {
        buffer.addAll(pcmChunk);
        
        final bufferDuration = PCMUtils.calculateDuration(buffer);
        
        if (bufferDuration >= chunkDurationSec) {
          final pcmData = PCMUtils.validatePCMBuffer(buffer)
              ? List<int>.from(buffer)
              : PCMUtils.trimToValidSamples(buffer);
          buffer.clear();
          
          // Don't transcribe empty buffers
          if (pcmData.isEmpty) {
            debugPrint('Skipping empty PCM buffer');
            return;
          }
          
          try {
            final result = await _transcribePCMInternal(pcmData, prompt, params);
            
            // Combine results
            if (combinedResult == null) {
              combinedResult = result;
            } else {
              combinedResult = CactusTranscriptionResult(
                success: result.success,
                text: "${combinedResult!.text} ${result.text}".trim(),
                timeToFirstTokenMs: combinedResult!.timeToFirstTokenMs,
                totalTimeMs: combinedResult!.totalTimeMs + result.totalTimeMs,
                tokensPerSecond: result.tokensPerSecond,
              );
            }
            
            onChunk?.call(result);
          } catch (e) {
            debugPrint('Failed to transcribe audio chunk: $e');
            onChunk?.call(CactusTranscriptionResult(
              success: false,
              text: '',
              errorMessage: e.toString(),
            ));
          }
        }
      },
      onError: (error) {
        debugPrint('Audio stream error: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () async {
        // Process remaining buffer
        if (buffer.isNotEmpty) {
          final pcmData = PCMUtils.validatePCMBuffer(buffer)
              ? buffer
              : PCMUtils.trimToValidSamples(buffer);
          
          // Don't transcribe empty buffers
          if (pcmData.isEmpty) {
            debugPrint('Skipping empty final buffer');
            if (!completer.isCompleted) {
              completer.complete(combinedResult ?? CactusTranscriptionResult(
                success: false,
                text: '',
                errorMessage: 'No valid audio data received',
              ));
            }
            return;
          }
          
          try {
            final result = await _transcribePCMInternal(pcmData, prompt, params);
            
            if (combinedResult == null) {
              combinedResult = result;
            } else {
              combinedResult = CactusTranscriptionResult(
                success: result.success,
                text: "${combinedResult!.text} ${result.text}".trim(),
                timeToFirstTokenMs: combinedResult!.timeToFirstTokenMs,
                totalTimeMs: combinedResult!.totalTimeMs + result.totalTimeMs,
                tokensPerSecond: result.tokensPerSecond,
              );
            }
            
            onChunk?.call(result);
          } catch (e) {
            debugPrint('Failed to transcribe final buffer: $e');
          }
        }
        
        if (!completer.isCompleted) {
          completer.complete(combinedResult ?? CactusTranscriptionResult(
            success: false,
            text: '',
            errorMessage: 'No audio data received',
          ));
        }
      },
    );

    // Store subscription for potential cancellation
    completer.future.whenComplete(() => subscription.cancel());

    return completer.future;
  }

  Future<CactusStreamedTranscriptionResult> transcribeStream({
    String? audioFilePath,
    Stream<Uint8List>? audioStream,
    String prompt = whisperPrompt,
    CactusTranscriptionParams? params,
  }) async {
    if (audioFilePath == null && audioStream == null) {
      throw ArgumentError('Must provide either audioFilePath or audioStream');
    }
    
    if (audioFilePath != null && audioStream != null) {
      throw ArgumentError('Cannot provide both audioFilePath and audioStream');
    }

    // File transcription mode
    if (audioFilePath != null) {
      final transcriptionParams = params ?? defaultTranscriptionParams;
      final model = _lastInitializedModel ?? defaultInitParams.model;
      final currentHandle = await _getValidatedHandle(model: model);

      if (currentHandle != null) {
        try {
          final streamedResult = CactusContext.transcribeStream(
            currentHandle,
            audioFilePath,
            prompt,
            params: transcriptionParams,
          );
          streamedResult.result.then((result) {
            _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
          }).catchError((error) {
            _logTranscriptionTelemetry(null, model, success: false, message: error.toString());
          });

          return streamedResult;
        } catch (e) {
          debugPrint('Streaming transcription failed: $e');
          _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
          rethrow;
        }
      }

      throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
    }

    // Live streaming mode - handles buffering and token streaming
    final tokenController = StreamController<String>();
    final resultCompleter = Completer<CactusTranscriptionResult>();
    final List<int> buffer = [];
    CactusTranscriptionResult? combinedResult;

    final subscription = audioStream!.listen(
      (pcmChunk) async {
        buffer.addAll(pcmChunk);
        
        final bufferDuration = PCMUtils.calculateDuration(buffer);
        
        if (bufferDuration >= chunkDurationSec) {
          final pcmData = PCMUtils.validatePCMBuffer(buffer)
              ? List<int>.from(buffer)
              : PCMUtils.trimToValidSamples(buffer);
          buffer.clear();
          
          // Don't transcribe empty buffers
          if (pcmData.isEmpty) {
            debugPrint('Skipping empty PCM buffer');
            return;
          }
          
          try {
            final streamedResult = await _transcribePCMStreamInternal(pcmData, prompt, params);
            
            // Forward tokens
            streamedResult.stream.listen(
              (token) {
                if (!tokenController.isClosed) {
                  tokenController.add(token);
                }
              },
              onError: (error) {
                if (!tokenController.isClosed) {
                  tokenController.addError(error);
                }
              },
            );
            
            // Handle result
            streamedResult.result.then((result) {
              if (combinedResult == null) {
                combinedResult = result;
              } else {
                combinedResult = CactusTranscriptionResult(
                  success: result.success,
                  text: "${combinedResult!.text} ${result.text}".trim(),
                  timeToFirstTokenMs: combinedResult!.timeToFirstTokenMs,
                  totalTimeMs: combinedResult!.totalTimeMs + result.totalTimeMs,
                  tokensPerSecond: result.tokensPerSecond,
                );
              }
            });
          } catch (e) {
            debugPrint('Failed to transcribe audio chunk: $e');
            if (!tokenController.isClosed) {
              tokenController.addError(e);
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Audio stream error: $error');
        if (!tokenController.isClosed) {
          tokenController.addError(error);
        }
        if (!resultCompleter.isCompleted) {
          resultCompleter.completeError(error);
        }
      },
      onDone: () async {
        // Process remaining buffer
        if (buffer.isNotEmpty) {
          final pcmData = PCMUtils.validatePCMBuffer(buffer)
              ? buffer
              : PCMUtils.trimToValidSamples(buffer);
          
          // Don't transcribe empty buffers
          if (pcmData.isEmpty) {
            debugPrint('Skipping empty final buffer');
            if (!tokenController.isClosed) {
              tokenController.close();
            }
            if (!resultCompleter.isCompleted) {
              resultCompleter.complete(combinedResult ?? CactusTranscriptionResult(
                success: false,
                text: '',
                errorMessage: 'No valid audio data received',
              ));
            }
            return;
          }
          
          try {
            final streamedResult = await _transcribePCMStreamInternal(pcmData, prompt, params);
            
            streamedResult.stream.listen(
              (token) {
                if (!tokenController.isClosed) {
                  tokenController.add(token);
                }
              },
              onError: (error) {
                if (!tokenController.isClosed) {
                  tokenController.addError(error);
                }
              },
            );
            
            final result = await streamedResult.result;
            
            if (combinedResult == null) {
              combinedResult = result;
            } else {
              combinedResult = CactusTranscriptionResult(
                success: result.success,
                text: "${combinedResult!.text} ${result.text}".trim(),
                timeToFirstTokenMs: combinedResult!.timeToFirstTokenMs,
                totalTimeMs: combinedResult!.totalTimeMs + result.totalTimeMs,
                tokensPerSecond: result.tokensPerSecond,
              );
            }
          } catch (e) {
            debugPrint('Failed to transcribe final buffer: $e');
          }
        }
        
        if (!tokenController.isClosed) {
          tokenController.close();
        }
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(combinedResult ?? CactusTranscriptionResult(
            success: false,
            text: '',
            errorMessage: 'No audio data received',
          ));
        }
      },
    );

    // Clean up subscription when done
    resultCompleter.future.whenComplete(() => subscription.cancel());

    return CactusStreamedTranscriptionResult(
      stream: tokenController.stream,
      result: resultCompleter.future,
    );
  }

  // Internal helper methods
  Future<CactusTranscriptionResult> _transcribePCMInternal(
    List<int> pcmData,
    String prompt,
    CactusTranscriptionParams? params,
  ) async {
    // Validate PCM data is not empty
    if (pcmData.isEmpty) {
      debugPrint('ERROR: Cannot transcribe empty PCM data');
      return CactusTranscriptionResult(
        success: false,
        text: '',
        errorMessage: 'Empty PCM data provided',
      );
    }

    return await _handleLock.synchronized(() async {
      final transcriptionParams = params ?? defaultTranscriptionParams;
      final model = _lastInitializedModel ?? defaultInitParams.model;
      final currentHandle = await _getValidatedHandle(model: model);

      if (currentHandle != null) {
        reset();
        
        try {
          final result = await CactusContext.transcribePCM(
            currentHandle,
            pcmData,
            prompt,
            params: transcriptionParams,
          );
          _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
          return result;
        } catch (e) {
          debugPrint('PCM transcription failed: $e');
          _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
          rethrow;
        }
      }

      throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
    });
  }

  Future<CactusStreamedTranscriptionResult> _transcribePCMStreamInternal(
    List<int> pcmData,
    String prompt,
    CactusTranscriptionParams? params,
  ) async {
    // Validate PCM data is not empty
    if (pcmData.isEmpty) {
      debugPrint('ERROR: Cannot transcribe empty PCM data');
      final controller = StreamController<String>();
      controller.close();
      return CactusStreamedTranscriptionResult(
        stream: controller.stream,
        result: Future.value(CactusTranscriptionResult(
          success: false,
          text: '',
          errorMessage: 'Empty PCM data provided',
        )),
      );
    }

    final transcriptionParams = params ?? defaultTranscriptionParams;
    final model = _lastInitializedModel ?? defaultInitParams.model;
    final currentHandle = await _getValidatedHandle(model: model);

    if (currentHandle != null) {
      try {
        reset();

        final streamedResult = CactusContext.transcribePCMStream(
          currentHandle,
          pcmData,
          prompt,
          params: transcriptionParams,
        );
        streamedResult.result.then((result) {
          _logTranscriptionTelemetry(result, model, success: result.success, message: result.errorMessage);
        }).catchError((error) {
          _logTranscriptionTelemetry(null, model, success: false, message: error.toString());
        });

        return streamedResult;
      } catch (e) {
        debugPrint('PCM streaming transcription failed: $e');
        _logTranscriptionTelemetry(null, model, success: false, message: e.toString());
        rethrow;
      }
    }

    throw Exception('Model $_lastInitializedModel is not downloaded. Please download it before transcribing.');
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  void reset() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.resetContext(currentHandle);
    }
  }

  bool isLoaded() => _handle != null;

  Future<List<VoiceModel>> getVoiceModels() async {
    if (_models.isEmpty) {
      _models.addAll(await Supabase.fetchVoiceModels());
      for (var model in _models) {
        model.isDownloaded = await _isModelDownloaded(model.slug);
      }
    }
    return _models;
  }

  Future<int?> _getValidatedHandle({required String model}) async {
    if (_handle != null && (model == _lastInitializedModel)) {
      return _handle;
    }

    await initializeModel(params: CactusInitParams(model: model));
    return _handle;
  }

  void _logTranscriptionTelemetry(CactusTranscriptionResult? result, String model, {bool success = true, String? message}) {
    if (Telemetry.isInitialized) {
      Telemetry.instance?.logTranscription(result, model, message: message, success: success);
    }
  }

  Future<bool> _isModelDownloaded(String modelName) async {
    return await DownloadService.modelExists(modelName);
  }
}

class _AsyncLock {
  Completer<void>? _completer;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_completer != null) {
      await _completer!.future;
    }

    _completer = Completer<void>();

    try {
      return await fn();
    } finally {
      final completer = _completer;
      _completer = null;
      completer?.complete();
    }
  }
}