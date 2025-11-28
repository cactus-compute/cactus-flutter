import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  State<STTPage> createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  late CactusSTT _stt;

  List<VoiceModel> _voiceModels = [];
  String _selectedModel = "whisper-small";

  // State variables
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _isTranscribing = false;
  bool _isLoadingModels = false;
  bool _isUsingDefaultModel = false;
  String _outputText = "Ready to start. Select a model and initialize to begin.";
  CactusTranscriptionResult? _lastResponse;
  String _downloadProgress = "";
  double? _downloadPercentage;

  @override
  void initState() {
    super.initState();
    _stt = CactusSTT();
    _loadVoiceModels();
  }

  @override
  void dispose() {
    _stt.unload();
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

            // Transcription button
            ElevatedButton(
              onPressed: (_isInitializing || _isTranscribing || !_isModelLoaded || _isLoadingModels)
                  ? null
                  : _transcribeFromFile,
              child: _isTranscribing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Transcribing...'),
                      ],
                    )
                  : const Text('Transcribe Audio File'),
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

                      if (_lastResponse != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Transcription:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _lastResponse!.text,
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ),
                        ),
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
