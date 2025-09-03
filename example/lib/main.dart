import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deviceId = await CactusTelemetry.fetchDeviceId();

  if(deviceId != null) {
    CactusTelemetry.init(deviceId, cactusTelemetryToken: 'f3a1c0b0-4c6f-4261-ac15-0c03b12d83a2');
  }
  
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
  }

  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      outputText = 'Downloading model...';
    });
    
    try {
      final downloadSuccess = await lm.downloadModel();
      if (downloadSuccess) {
        setState(() {
          isModelDownloaded = true;
          outputText = 'Model downloaded successfully! Click "Initialize Model" to load it.';
        });
      } else {
        setState(() {
          outputText = 'Failed to download model.';
        });
      }
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
      final loadSuccess = await lm.initializeModel(CactusInitParams(contextSize: 2048));
      if (loadSuccess) {
        setState(() {
          isModelLoaded = true;
          outputText = 'Model initialized successfully! Ready to generate completions.';
        });
      } else {
        setState(() {
          outputText = 'Failed to initialize model.';
        });
      }
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
        messages: [ChatMessage(content: 'Hi, tell me a short joke', role: "user")], 
        params: CactusCompletionParams(bufferSize: 1024, maxTokens: 50)
      );
      
      if (resp != null && resp.success) {
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

  @override
  void dispose() {
    destroyContext();
    super.dispose();
  }

  void destroyContext() {
    lm.unload();
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
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isDownloading || isInitializing || !isModelLoaded) ? null : generateCompletion,
              child: const Text('Generate'),
            ),
            const SizedBox(height: 20),
            
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
