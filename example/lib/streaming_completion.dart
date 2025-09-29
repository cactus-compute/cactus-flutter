import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class StreamingCompletionPage extends StatefulWidget {
  const StreamingCompletionPage({super.key});

  @override
  State<StreamingCompletionPage> createState() => _StreamingCompletionPageState();
}

class _StreamingCompletionPageState extends State<StreamingCompletionPage> {
  final lm = CactusLM();
  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isDownloading = false;
  bool isInitializing = false;
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  String? lastResponse;
  double? lastTPS;
  double? lastTTFT;

  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
  }

  @override
  void dispose() {
    lm.unload();
    super.dispose();
  }

  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      outputText = 'Downloading model...';
    });
    
    try {
      await lm.downloadModel(
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            if (isError) {
              outputText = 'Error: $status';
            } else {
              outputText = status;
              if (progress != null) {
                outputText += ' (${(progress * 100).toStringAsFixed(1)}%)';
              }
            }
          });
        },
      );
      setState(() {
        isModelDownloaded = true;
        outputText = 'Model downloaded successfully! Click "Initialize Model" to load it.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error downloading model: $e';
      });
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> initializeModel() async {
    setState(() {
      isInitializing = true;
      outputText = 'Initializing model...';
    });
    
    try {
      await lm.initializeModel();
      setState(() {
        isModelLoaded = true;
        outputText = 'Model initialized successfully! Ready to generate completions.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error initializing model: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> generateStreamCompletion() async {
    if (!isModelLoaded) {
      setState(() {
        outputText = 'Please download and initialize model first.';
      });
      return;
    }
    
    setState(() {
      isInitializing = true;
      outputText = 'Generating stream response...';
      lastResponse = '';
      lastTPS = null;
      lastTTFT = null;
    });
    
    try {
      final streamedResult = await lm.generateCompletionStream(
        messages: [ChatMessage(content: 'Tell me a story', role: "user")]
      );

      await for (final chunk in streamedResult.stream) {
        setState(() {
          lastResponse = (lastResponse ?? '') + chunk;
        });
      }
      
      final resp = await streamedResult.result;
      if (resp.success) {
        setState(() {
          lastResponse = resp.response;
          lastTPS = resp.tokensPerSecond;
          lastTTFT = resp.timeToFirstTokenMs;
          outputText = 'Stream generation completed successfully!';;
        });
      } else {
        setState(() {
          outputText = 'Failed to generate response.';
          lastResponse = null;
          lastTPS = null;
          lastTTFT = null;
        });
      }
    } catch (e) {
      setState(() {
        outputText = 'Error generating stream response: $e';
        lastResponse = null;
        lastTPS = null;
        lastTTFT = null;
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming Completion'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buttons section
            ElevatedButton(
              onPressed: isDownloading ? null : downloadModel,
              child: Text(isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeModel,
              child: Text(isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : generateStreamCompletion,
              child: const Text('Run Streaming Example'),
            ),

            // Status section
            if (isDownloading || isInitializing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Processing...'),
                  ],
                ),
              ),
            
            // Output section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(outputText),
                    if (lastResponse != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Response:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(lastResponse!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('TTFT', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${lastTTFT?.toStringAsFixed(2)} ms'),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('TPS', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${lastTPS?.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
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