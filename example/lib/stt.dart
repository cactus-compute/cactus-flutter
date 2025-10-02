import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

class STTPage extends StatefulWidget {
  const STTPage({super.key});

  @override
  State<STTPage> createState() => _STTPageState();
}

class _STTPageState extends State<STTPage> {
  final CactusSTT _stt = CactusSTT();
  List<VoiceModel> _voiceModels = [];
  String _selectedModel = "vosk-en-us";
  
  // State variables to match Kotlin implementation
  bool _isModelDownloaded = false;
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _isTranscribing = false;
  String _outputText = "Ready to start. Click 'Download Model' to begin.";
  SpeechRecognitionResult? _lastResponse;
  String _downloadProgress = "";
  double? _downloadPercentage;

  @override
  void initState() {
    super.initState();
    _loadVoiceModels();
  }

  @override
  void dispose() {
    _stt.stop();
    _stt.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceModels() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final models = await _stt.getVoiceModels();
      setState(() {
        _voiceModels = models;
        _isDownloading = false;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voice models: $e')),
        );
      }
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _outputText = "Downloading model...";
      _downloadProgress = "Starting download...";
      _downloadPercentage = null;
    });

    try {
      final success = await _stt.download(
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
        if (success) {
          _isModelDownloaded = true;
          _outputText = "Model downloaded successfully! Click 'Initialize Model' to load it.";
        } else {
          _outputText = "Failed to download model.";
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = "";
        _downloadPercentage = null;
        _outputText = "Error downloading model: ${e.toString()}";
      });
    }
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isInitializing = true;
      _outputText = "Initializing model...";
    });

    try {
      final success = await _stt.init(model: _selectedModel);
      setState(() {
        _isInitializing = false;
        if (success) {
          _isModelLoaded = true;
          _outputText = "Model initialized successfully! Ready to test transcription.";
        } else {
          _outputText = "Failed to initialize model.";
        }
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _outputText = "Error initializing model: ${e.toString()}";
      });
    }
  }

  Future<void> _transcribeAudio() async {
    if (!_isModelLoaded) {
      setState(() {
        _outputText = "Please download and initialize model first.";
      });
      return;
    }

    try {
      setState(() {
        _isTranscribing = true;
        _outputText = "Listening...";
      });

      // Start transcription and wait for result
      final result = await _stt.transcribe();
      
      setState(() {
        _isTranscribing = false;
        if (result != null && result.success) {
          _lastResponse = result;
          _outputText = "Transcription completed successfully!";
        } else {
          _outputText = "Failed to transcribe.";
          _lastResponse = null;
        }
      });
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _outputText = "Error transcribing: ${e.toString()}";
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
            if (_isDownloading || _isInitializing || _isTranscribing) 
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
                      'Transcription Demo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This example demonstrates transcription capabilities using a local speech-to-text model. You can download the model, initialize it, and then transcribe audio input.',
                    ),
                    const SizedBox(height: 16),
                    const Text('Voice Models', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_voiceModels.isEmpty)
                      const Text('Loading voice models...')
                    else
                      DropdownButton<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        items: _voiceModels.map((model) => DropdownMenuItem(
                          value: model.slug,
                          child: Text('${model.slug} (${model.language}) - ${model.sizeMb}MB'),
                        )).toList(),
                        onChanged: (value) {
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
            
            // Buttons section
            ElevatedButton(
              onPressed: _isDownloading ? null : _downloadModel,
              child: _isDownloading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _downloadPercentage,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_downloadProgress.isNotEmpty ? _downloadProgress : 'Downloading...'),
                      ],
                    )
                  : Text(_isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
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
            
            ElevatedButton(
              onPressed: (_isInitializing || _isDownloading) ? null : _initializeModel,
              child: _isInitializing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Initializing...'),
                      ],
                    )
                  : Text(_isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: (_isDownloading || _isInitializing || _isTranscribing || !_isModelLoaded) 
                  ? null 
                  : _transcribeAudio,
              child: _isTranscribing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Listening...'),
                      ],
                    )
                  : const Text('Transcribe Audio'),
            ),
            
            const SizedBox(height: 16),
            
            // Output section
            Card(
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
                        'Model Response:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.grey.shade200,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            _lastResponse?.text ?? '',
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}