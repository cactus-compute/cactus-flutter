import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cactus Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final lm = CactusLM();
  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isDownloading = false;
  bool isInitializing = false;
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  String? lastResponse;
  double? lastTPS;
  double? lastTTFT;
  List<CactusModel> availableModels = [];

  @override
  void initState() {
    super.initState();
    getAvailableModels();
  }

  @override
  void dispose() {
    lm.unload();
    super.dispose();
  }

  Future<void> getAvailableModels() async {
    try {
      final models = await lm.getModels();
      print("Available models: ${models.map((m) => "${m.slug}: ${m.sizeMb}MB").join(", ")}");
    } catch (e) {
      print("Error fetching models: $e");
    }
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

  Future<void> generateCompletion() async {
    if (!isModelLoaded) {
      setState(() {
        outputText = 'Please download and initialize model first.';
      });
      return;
    }
    
    setState(() {
      isInitializing = true;
      outputText = 'Generating response...';
    });
    
    try {
      final resp = await lm.generateCompletion(
        messages: [ChatMessage(content: 'How is the weather in New York?', role: "user")],
        params: CactusCompletionParams(
          bufferSize: 2048,
        )
      );
      
      if (resp.success) {
        setState(() {
          lastResponse = resp.response;
          lastTPS = resp.tokensPerSecond;
          lastTTFT = resp.timeToFirstTokenMs;
          outputText = 'Generation completed successfully!';
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
        outputText = 'Error generating response: $e';
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
        messages: [ChatMessage(content: 'Tell me a joke', role: "user")]
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

  Future<void> generateEmbeddings() async {
    final resp = await lm.generateEmbedding(
      text: 'Hi, tell me a short joke',
      bufferSize: 1024,
    );

    if (resp.success) {
      setState(() {
        lastResponse = "Dimensions: ${resp.dimension.toString()} \nLength: ${resp.embeddings.length} \nEmbeddings: [${resp.embeddings.take(5).join(', ')}...]";
        outputText = 'Embedding generation completed successfully!';
      });
    } else {
      setState(() {
        outputText = 'Failed to generate embedding.';
        lastResponse = null;
        lastTPS = null;
        lastTTFT = null;
      });
    }
  }

  Future<void> toolCall() async {
    if (!isModelLoaded) {
      setState(() {
        outputText = 'Please download and initialize model first.';
      });
      return;
    }
    
    setState(() {
      isInitializing = true;
      outputText = 'Generating response...';
    });
    
    try {
      final resp = await lm.generateCompletion(
        messages: [ChatMessage(content: 'How is the weather in New York?', role: "user")],
        params: CactusCompletionParams(
          tools: [
            CactusTool(
              name: 'get_weather',
              description: 'Get weather for a location',
              parameters: ToolParametersSchema(
                properties: {
                  'location': ToolParameter(type: 'string', description: 'City name', required: true),
                },
              ),
            ),
          ],
        )
      );
      
      if (resp.success) {
        setState(() {
          lastResponse = resp.toolCalls.isNotEmpty
              ? 'Tool Call: ${resp.toolCalls.last.name}\nArguments: ${resp.toolCalls.last.arguments}'
              : resp.response;
          lastTPS = resp.tokensPerSecond;
          lastTTFT = resp.timeToFirstTokenMs;
          outputText = 'Generation completed successfully!';
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
        outputText = 'Error generating response: $e';
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
        title: const Text('Cactus Demo'),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : generateCompletion,
                      child: const Text('Generate'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : generateStreamCompletion,
                      child: const Text('Streaming'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : generateEmbeddings,
                      child: const Text('Embeddings'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : toolCall,
                      child: const Text('Tool Call'),
                    ),
                  ),
                ],
              ),
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
