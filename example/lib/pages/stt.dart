import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  State<STTPage> createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  late CactusSTT _stt;
  late AudioRecorder _recorder;

  List<VoiceModel> _voiceModels = [];
  String _selectedModel = "whisper-small";

  // State variables
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _isTranscribing = false;
  bool _isLoadingModels = false;
  bool _isUsingDefaultModel = false;
  bool _isRecording = false;
  String _outputText = "Ready to start. Select a model and initialize to begin.";
  CactusTranscriptionResult? _lastResponse;
  String _downloadProgress = "";
  double? _downloadPercentage;
  String _streamedText = "";

  // Audio buffer for recording
  final List<int> _audioBuffer = [];
  StreamSubscription<Uint8List>? _recordingSubscription;

  @override
  void initState() {
    super.initState();
    _stt = CactusSTT();
    _recorder = AudioRecorder();
    _loadVoiceModels();
  }

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    if (_isRecording) {
      _recorder.stop();
    }
    _stt.unload();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceModels() async {
    setState(() {
      _isLoadingModels = true;
    });

    try {
      final models = await _stt.getVoiceModels();
      setState(() {
        _voiceModels = models;
        _isLoadingModels = false;
        _isUsingDefaultModel = false;
        if (models.isNotEmpty) {
          if (!models.any((model) => model.slug == _selectedModel)) {
            _selectedModel = models.first.slug;
          }
          _outputText = "Models loaded. Select model and click 'Download & Initialize Model' to begin.";
        } else {
          _outputText = "No models available.";
        }
      });
    } catch (e) {
      const defaultSlug = "whisper-small";
      setState(() {
        _voiceModels = [];
        _selectedModel = defaultSlug;
        _isLoadingModels = false;
        _isUsingDefaultModel = true;
        _outputText = "Network error loading models. Using default model: $defaultSlug";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error. Using default model: $defaultSlug')),
        );
      }
    }
  }

  Future<void> _downloadAndInitializeModel() async {
    setState(() {
      _isDownloading = true;
      _isInitializing = true;
      _outputText = "Downloading and initializing model...";
      _downloadProgress = "Starting download...";
      _downloadPercentage = null;
    });

    try {
      // Download the model
      await _stt.downloadModel(
        model: _selectedModel,
        downloadProcessCallback: (progress, message, isError) {
          setState(() {
            if (progress != null) {
              _downloadPercentage = progress;
              _downloadProgress = "${(progress * 100).toStringAsFixed(1)}%";
            } else {
              _downloadProgress = message;
            }
          });
        },
      );

      setState(() {
        _isDownloading = false;
        _downloadProgress = "";
        _downloadPercentage = null;
        _outputText = "Model downloaded successfully! Initializing...";
      });

      // Initialize the model
      await _stt.initializeModel(params: CactusInitParams(model: _selectedModel));

      setState(() {
        _isInitializing = false;
        _isModelLoaded = true;
        _outputText = "Model downloaded and initialized successfully! Ready to transcribe audio.";
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _isInitializing = false;
        _downloadProgress = "";
        _downloadPercentage = null;
        _outputText = "Error: ${e.toString()}";
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_isModelLoaded) {
      setState(() {
        _outputText = "Please initialize the model first.";
      });
      return;
    }

    if (!await _recorder.hasPermission()) {
      setState(() {
        _outputText = "Microphone permission denied.";
      });
      return;
    }

    try {
      // Clear previous buffer
      _audioBuffer.clear();

      // Start audio stream with PCM16 format
      final stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      setState(() {
        _isRecording = true;
        _outputText = "Recording... Tap Stop to transcribe";
        _lastResponse = null;
        _streamedText = "";
      });

      // Collect audio chunks into buffer
      _recordingSubscription = stream.listen(
        (audioChunk) {
          _audioBuffer.addAll(audioChunk);
        },
        onError: (error) {
          setState(() {
            _isRecording = false;
            _outputText = "Error during recording: ${error.toString()}";
          });
        },
      );
    } catch (e) {
      setState(() {
        _isRecording = false;
        _outputText = "Error starting recording: ${e.toString()}";
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      // Stop recording and cancel subscription
      await _recorder.stop();
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;

      setState(() {
        _isRecording = false;
        _outputText = "Stopping recording and transcribing...";
      });

      if (_audioBuffer.isNotEmpty) {
        // Convert buffer to Uint8List
        final audioData = Uint8List.fromList(_audioBuffer);

        setState(() {
          _isTranscribing = true;
          _outputText = "Transcribing recorded audio...";
        });

        String streamedText = "";

        try {
          // Transcribe from audio buffer
          final streamedResult = await _stt.transcribeStream(
            audioStream: Stream.value(audioData),
          );

          // Listen to the token stream
          streamedResult.stream.listen(
            (token) {
              setState(() {
                streamedText += token;
                _streamedText = streamedText;
              });
            },
            onError: (error) {
              setState(() {
                _isTranscribing = false;
                _outputText = "Error during streaming: ${error.toString()}";
                _lastResponse = null;
              });
            },
          );

          // Wait for the final result
          final transcriptionResult = await streamedResult.result;

          setState(() {
            _isTranscribing = false;
            if (transcriptionResult.success) {
              _lastResponse = transcriptionResult;
              _streamedText = transcriptionResult.text;
              _outputText = "Mic transcription completed successfully!";
            } else {
              _outputText = transcriptionResult.errorMessage ?? "Failed to transcribe recorded audio.";
              _lastResponse = null;
            }
          });
        } catch (e) {
          setState(() {
            _isTranscribing = false;
            _outputText = "Error during transcription: ${e.toString()}";
            _lastResponse = null;
          });
        } finally {
          // Clear buffer after transcription
          _audioBuffer.clear();
        }
      } else {
        setState(() {
          _outputText = "No audio data recorded.";
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
        _outputText = "Error stopping recording: ${e.toString()}";
      });
    }
  }

  Future<void> _transcribeFromFile() async {
    if (!_isModelLoaded) {
      setState(() {
        _outputText = "Please initialize the model first.";
      });
      return;
    }

    try {
      // Use file picker to select .wav files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav'],
        dialogTitle: 'Select a .wav audio file',
      );

      if (result != null && result.files.single.path != null) {
        final String audioFilePath = result.files.single.path!;

        setState(() {
          _isTranscribing = true;
          _outputText = "Transcribing audio file: ${result.files.single.name}";
          _lastResponse = null;
        });

        // Create a temporary result to accumulate streamed text
        String streamedText = "";

        try {
          // Start streaming transcription from file
          final streamedResult = await _stt.transcribeStream(
            audioFilePath: audioFilePath,
          );

          // Listen to the token stream
          streamedResult.stream.listen(
            (token) {
              setState(() {
                streamedText += token;
                _outputText = "Transcribing: $streamedText";
              });
            },
            onError: (error) {
              setState(() {
                _isTranscribing = false;
                _outputText = "Error during streaming: ${error.toString()}";
                _lastResponse = null;
              });
            },
          );

          // Wait for the final result
          final transcriptionResult = await streamedResult.result;

          setState(() {
            _isTranscribing = false;
            if (transcriptionResult.success) {
              _lastResponse = transcriptionResult;
              _outputText = "File transcription completed successfully!";
            } else {
              _outputText = transcriptionResult.errorMessage ?? "Failed to transcribe audio file.";
              _lastResponse = null;
            }
          });
        } catch (e) {
          setState(() {
            _isTranscribing = false;
            _outputText = "Error during transcription: ${e.toString()}";
            _lastResponse = null;
          });
        }
      } else {
        // User cancelled the picker
        setState(() {
          _outputText = "File selection cancelled.";
        });
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _outputText = "Error during file transcription: ${e.toString()}";
        _lastResponse = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech-to-Text'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isDownloading || _isInitializing || _isTranscribing || _isLoadingModels)
              const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                backgroundColor: Colors.grey,
              ),
            const SizedBox(height: 8),

            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_isLoadingModels)
                      const Text('Loading models...')
                    else if (_isUsingDefaultModel)
                      Text('Using default model: $_selectedModel')
                    else if (_voiceModels.isEmpty)
                      const Text('No models available')
                    else
                      DropdownButton<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        items: _voiceModels.map((model) => DropdownMenuItem(
                          value: model.slug,
                          child: Text('${model.slug} (${model.sizeMb}MB)'),
                        )).toList(),
                        onChanged: _isModelLoaded ? null : (value) {
                          setState(() {
                            _selectedModel = value!;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Initialize model button
            ElevatedButton(
              onPressed: (_isDownloading || _isInitializing || _isModelLoaded || _isLoadingModels || (_voiceModels.isEmpty && !_isUsingDefaultModel)) ? null : _downloadAndInitializeModel,
              child: (_isDownloading || _isInitializing)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _downloadPercentage,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_downloadProgress.isNotEmpty ? _downloadProgress : (_isDownloading ? 'Downloading...' : 'Initializing...')),
                      ],
                    )
                  : Text(_isModelLoaded ? 'Model Ready ✓' : 'Download & Initialize Model'),
            ),

            // Show linear progress indicator during download
            if (_isDownloading && _downloadPercentage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(
                  value: _downloadPercentage,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                  backgroundColor: Colors.grey.shade300,
                ),
              ),

            const SizedBox(height: 4),

            // Transcription buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isInitializing || _isTranscribing || !_isModelLoaded || _isLoadingModels || _isRecording)
                        ? null
                        : _transcribeFromFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Pick File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isInitializing || !_isModelLoaded || _isLoadingModels || _isTranscribing)
                        ? null
                        : _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 18),
                    label: Text(_isRecording ? 'Stop' : 'Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Recording status indicator
            if (_isRecording)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Recording... Tap Stop to transcribe',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Output section
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Output:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _outputText,
                        style: const TextStyle(fontSize: 15),
                      ),

                      if (_isTranscribing || _lastResponse != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Transcription:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _streamedText.isNotEmpty ? _streamedText : (_lastResponse?.text ?? ''),
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ),
                        if (_lastResponse != null) ...[
                          const SizedBox(height: 16),
                          // Metrics row at the bottom
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Model',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedModel,
                                        style: const TextStyle(fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'TTFT',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_lastResponse!.timeToFirstTokenMs.toStringAsFixed(2)} ms',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(_lastResponse!.totalTimeMs / 1000).toStringAsFixed(2)} s',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
