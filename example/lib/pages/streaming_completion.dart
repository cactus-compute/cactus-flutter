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
  bool isGenerating = false;
  bool isStreaming = false;
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  String? lastResponse;
  double lastTPS = 0;
  double lastTTFT = 0;
  String model = 'qwen3-0.6';
  List<CactusModel> availableModels = [];

  @override
  void initState() {
    super.initState();
    getAvailableModels();
  }

  Future<void> getAvailableModels() async {
    try {
      final models = await lm.getModels();
      debugPrint("Available models: ${models.map((m) => "${m.slug}: ${m.sizeMb}MB").join(", ")}");
      setState(() {
        availableModels = models;
      });
    } catch (e) {
      debugPrint("Error fetching models: $e");
    }
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
        model: model,
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
      await lm.initializeModel(
        params: CactusInitParams(model: model)
      );
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
      isGenerating = true;
      isStreaming = false;
      outputText = 'Generating stream response...';
      lastResponse = '';
      lastTPS = 0;
      lastTTFT = 0;
    });
    
    try {
      final streamedResult = await lm.generateCompletionStream(
        params: CactusCompletionParams(
          maxTokens: 200
        ),
        messages: [
          ChatMessage(content: 'You are Cactus, a very capable AI assistant running offline on a smartphone', role: "system"), 
          ChatMessage(content: 'Hi, how are you?', role: "user")
        ],
      );

      await for (final chunk in streamedResult.stream) {
        setState(() {
          // Hide processing indicator once streaming starts
          if (!isStreaming) {
            isGenerating = false;
            isStreaming = true;
            outputText = 'Streaming response...';
          }
          lastResponse = (lastResponse ?? '') + chunk;
        });
      }
      
      final resp = await streamedResult.result;
      if (resp.success) {
        setState(() {
          lastResponse = resp.response;
          lastTPS = resp.tokensPerSecond;
          lastTTFT = resp.timeToFirstTokenMs;
          outputText = 'Stream generation completed successfully!';
          isStreaming = false;
        });
      } else {
        setState(() {
          outputText = 'Failed to generate response.';
          lastResponse = null;
          lastTPS = 0;
          lastTTFT = 0;
          isStreaming = false;
        });
      }
    } catch (e) {
      setState(() {
        outputText = 'Error generating stream response: $e';
        lastResponse = null;
        lastTPS = 0;
        lastTTFT = 0;
        isStreaming = false;
      });
    } finally {
      setState(() {
        isGenerating = false;
        isStreaming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Streaming Completion'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                ),
                const SizedBox(height: 10),
                // Buttons section
                ElevatedButton(
              onPressed: isDownloading ? null : downloadModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isDownloading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Downloading...'),
                    ],
                  )
                : Text(isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isInitializing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Initializing...'),
                    ],
                  )
                : Text(isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isDownloading || isInitializing || isGenerating || !isModelLoaded) ? null : generateStreamCompletion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isGenerating && !isStreaming 
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...'),
                    ],
                  )
                : const Text('Run Streaming Example'),
            ),

            const SizedBox(height: 20),
            
            // Output section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(outputText, style: const TextStyle(color: Colors.black)),
                    if (lastResponse != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Response:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(lastResponse!, style: const TextStyle(color: Colors.black)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Model', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                              Text(model, style: const TextStyle(color: Colors.black)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('TTFT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                              Text('${lastTTFT.toStringAsFixed(2)} ms', style: const TextStyle(color: Colors.black)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('TPS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                              Text(lastTPS.toStringAsFixed(2), style: const TextStyle(color: Colors.black)),
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
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: DropdownMenu(
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: availableModels
                  .map((model) => DropdownMenuEntry(
                      value: model.slug,
                      label: '${model.slug} (${model.sizeMb}MB)'))
                  .toList(),
              initialSelection: model,
              onSelected: (String? value) {
                if (value != null) {
                  setState(() {
                    model = value;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}