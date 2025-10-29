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
  num lastTPS = 0;
  num lastTTFT = 0;
  String model = 'qwen3-0.6';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    lm.dispose();
    super.dispose();
  }

  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      outputText = 'Downloading model...';
    });
    
    try {
      await lm.download(
        modelUrl: "https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf"
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
      await lm.init(
        modelFilename: 'Qwen3-0.6B-Q8_0.gguf',
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

      final streamedResult = await lm.completion(
        [
          ChatMessage(content: '/no_think You are a helpful assistant. Be concise and friendly in your responses.', role: "system"), 
          ChatMessage(content: 'What is your name?', role: "user")
        ],
        maxTokens: 200,
        onToken: (String token) {
          setState(() {
            lastResponse = (lastResponse ?? '') + token;
          });
          return true;
        },
        stopSequences: ['<|im_end|>', '</s>'],
      );
      setState(() {
        lastResponse = streamedResult.text;
        lastTPS = streamedResult.tokensPerSecond ?? 0;
        lastTTFT = streamedResult.timeToFirstTokenMs ?? 0;
        outputText = 'Stream generation completed successfully!';
        isStreaming = false;
      });
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
              // Buttons section
            ElevatedButton(
              onPressed: isDownloading ? null : downloadModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isDownloading ? const Row(
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
              ) : Text(isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isInitializing ? const Row(
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
              ): Text(isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
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
    );
  }
}