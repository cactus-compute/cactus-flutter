import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  State<STTPage> createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  TranscriptionProvider _currentProvider = TranscriptionProvider.whisper;
  late CactusSTT _stt;
  
  List<VoiceModel> _voiceModels = [];
  String _selectedModel = "tiny";
  
  // State variables
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _isTranscribing = false;
  bool _isLoadingModels = false;
  bool _isUsingDefaultModel = false;
  String _outputText = "Ready to start. Select a model and initialize to begin.";
  SpeechRecognitionResult? _lastResponse;
  String _downloadProgress = "";
  double? _downloadPercentage;

  @override
  void initState() {
    super.initState();
    _stt = CactusSTT(provider: _currentProvider);
    _loadVoiceModels();
  }

  @override
  void dispose() {
    _stt.stop();
    _stt.dispose();
    super.dispose();
  }

  void _resetState() {
    _isModelLoaded = false;
    _isDownloading = false;
    _isInitializing = false;
    _isTranscribing = false;
    _isLoadingModels = false;
    _isUsingDefaultModel = false;
    _voiceModels = [];
    _lastResponse = null;
    _downloadProgress = "";
    _downloadPercentage = null;
    _selectedModel = "tiny";
    _outputText = "Ready to start. Select a model and initialize to begin.";
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
      // Use default model slug on network failure
      final defaultSlug = _currentProvider == TranscriptionProvider.whisper
          ? "whisper-tiny"
          : "";

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
      final downloadSuccess = await _stt.download(
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

      if (!downloadSuccess) {
        setState(() {
          _isDownloading = false;
          _isInitializing = false;
          _downloadProgress = "";
          _downloadPercentage = null;
          _outputText = "Failed to download model.";
        });
        return;
      }

      setState(() {
        _isDownloading = false;
        _downloadProgress = "";
        _downloadPercentage = null;
        _outputText = "Model downloaded successfully! Initializing...";
      });

      // Initialize the model
      final initSuccess = await _stt.init(model: _selectedModel);
      setState(() {
        _isInitializing = false;
        if (initSuccess) {
          _isModelLoaded = true;
          _outputText = "Model downloaded and initialized successfully! Ready to transcribe audio.";
        } else {
          _outputText = "Failed to initialize model.";
        }
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

  Future<void> _transcribeFromMicrophone() async {
    if (!_isModelLoaded) {
      setState(() {
        _outputText = "Please initialize the model first.";
      });
      return;
    }

    try {
      setState(() {
        _isTranscribing = true;
        _outputText = "Listening for audio... Speak now!";
      });

      final params = SpeechRecognitionParams(
        sampleRate: 16000,
        maxDuration: 30000, // 30 seconds
        maxSilenceDuration: 3000, // 3 seconds of silence
        silenceThreshold: 500.0,
      );
      final result = await _stt.transcribe(params: params);
      
      setState(() {
        _isTranscribing = false;
        if (result != null && result.success) {
          _lastResponse = result;
          _outputText = "Transcription completed successfully!";
        } else {
          _outputText = result?.text ?? "Failed to transcribe audio.";
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
        });

        final params = SpeechRecognitionParams(
          sampleRate: 16000,
        );

        // Start transcription from file
        final transcriptionResult = await _stt.transcribe(
          params: params,
          filePath: audioFilePath,
        );
        
        setState(() {
          _isTranscribing = false;
          if (transcriptionResult != null && transcriptionResult.success) {
            _lastResponse = transcriptionResult;
            _outputText = "File transcription completed successfully!";
          } else {
            _outputText = transcriptionResult?.text ?? "Failed to transcribe audio file.";
            _lastResponse = null;
          }
        });
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

  void _stopTranscription() {
    _stt.stop();
    setState(() {
      _outputText = "Processing recorded audio...";
    });
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
            const SizedBox(height: 16),
            
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speech-to-Text Transcription Demo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This example demonstrates speech-to-text transcription using CactusSTT. Select a provider and model, initialize it, then you can transcribe from microphone input or from audio files.',
                    ),
                    const SizedBox(height: 16),
                    const Text('Provider Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<TranscriptionProvider>(
                      value: _currentProvider,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: TranscriptionProvider.whisper,
                          child: Text('Whisper'),
                        ),
                      ],
                      onChanged: _isModelLoaded ? null : (value) {
                        if (value != null && value != _currentProvider) {
                          setState(() {
                            _currentProvider = value;
                            _resetState();
                          });
                          _stt.dispose();
                          _stt = CactusSTT(provider: _currentProvider);
                          _loadVoiceModels();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Model Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
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
            
            const SizedBox(height: 16),
            
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
            
            const SizedBox(height: 8),
            
            // Transcription buttons in a row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isDownloading || _isInitializing || !_isModelLoaded || _isLoadingModels) 
                        ? null 
                        : (_isTranscribing ? _stopTranscription : _transcribeFromMicrophone),
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
                              const Text('Stop Recording'),
                            ],
                          )
                        : const Text('Microphone'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isInitializing || _isTranscribing || !_isModelLoaded || _isLoadingModels) 
                        ? null 
                        : _transcribeFromFile,
                    child: const Text('File'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
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
                      Text(_outputText),
                      
                      if (_lastResponse != null) ...[
                        const Divider(),
                        const Text(
                          'Transcription Result:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lastResponse!.text,
                                      style: const TextStyle(fontSize: 16, color: Colors.black),
                                    ),
                                    if (_lastResponse!.processingTime != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Processing time: ${_lastResponse!.processingTime!.toStringAsFixed(0)}ms',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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