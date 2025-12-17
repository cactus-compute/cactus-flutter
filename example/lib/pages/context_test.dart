import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class ContextTestPage extends StatefulWidget {
  const ContextTestPage({super.key});

  @override
  State<ContextTestPage> createState() => _ContextTestPageState();
}

class _ContextTestPageState extends State<ContextTestPage> {
  final lm = CactusLM();
  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isDownloading = false;
  bool isInitializing = false;
  bool isRunningTest = false;
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  String? testResponse;
  double testTPS = 0;
  double testTTFT = 0;
  double testTotalTime = 0;
  int testPrefillTokens = 0;
  int testDecodeTokens = 0;
  int testTotalTokens = 0;
  String model = 'qwen3-0.6';
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
      debugPrint("Available models: ${models.map((m) => "${m.slug}: ${m.sizeMb}MB").join(", ")}");
      setState(() {
        availableModels = models;
      });
    } catch (e) {
      debugPrint("Error fetching models: $e");
    }
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
        outputText = 'Model initialized successfully! Ready to run 4K context test.';
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

  Future<void> run4KContextTest() async {
    if (!isModelLoaded) {
      setState(() {
        outputText = 'Please download and initialize model first.';
      });
      return;
    }

    setState(() {
      isRunningTest = true;
      outputText = 'Running 4K context test...';
      testResponse = null;
      testTPS = 0;
      testTTFT = 0;
      testTotalTime = 0;
      testPrefillTokens = 0;
      testDecodeTokens = 0;
      testTotalTokens = 0;
    });

    try {
      // Build system message with 230 context items
      StringBuffer systemContent = StringBuffer('/no_think You are helpful. ');
      for (int i = 0; i < 230; i++) {
        systemContent.write('Context $i: Background knowledge. ');
      }

      // Build user message with 230 data items
      StringBuffer userContent = StringBuffer();
      for (int i = 0; i < 230; i++) {
        final dataValue = i * 3.14159;
        userContent.write('Data $i = $dataValue. ');
      }
      userContent.write('Explain the data.');

      debugPrint('System message length: ${systemContent.length} chars');
      debugPrint('User message length: ${userContent.length} chars');

      final resp = await lm.generateCompletion(
        messages: [
          ChatMessage(content: systemContent.toString(), role: "system"),
          ChatMessage(content: userContent.toString(), role: "user")
        ],
        params: CactusCompletionParams(
          maxTokens: 100
        )
      );

      if (resp.success) {
        setState(() {
          testResponse = resp.response;
          testTPS = resp.tokensPerSecond;
          testTTFT = resp.timeToFirstTokenMs;
          testTotalTime = resp.totalTimeMs;
          testPrefillTokens = resp.prefillTokens;
          testDecodeTokens = resp.decodeTokens;
          testTotalTokens = resp.totalTokens;
          outputText = '4K context test completed successfully!';
        });
      } else {
        setState(() {
          outputText = 'Test failed to generate response.';
        });
      }
    } catch (e) {
      setState(() {
        outputText = 'Error running test: $e';
      });
    } finally {
      setState(() {
        isRunningTest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('4K Context Test'),
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
                const SizedBox(height: 56),
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
                  onPressed: (isInitializing || isDownloading) ? null : initializeModel,
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
                  onPressed: (isDownloading || isInitializing || isRunningTest || !isModelLoaded) ? null : run4KContextTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: isRunningTest
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
                          Text('Running Test...'),
                        ],
                      )
                    : const Text('Run 4K Context Test'),
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
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Test Results:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          ),
                          const SizedBox(height: 8),

                          Text(outputText, style: const TextStyle(color: Colors.black)),
                          if (testResponse != null) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.black),
                            const SizedBox(height: 16),

                            // Performance Metrics Section
                            const Text(
                              'Performance Metrics:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                            ),
                            const SizedBox(height: 8),
                            _buildMetricRow('Model', model),
                            _buildMetricRow('Time to First Token', '${testTTFT.toStringAsFixed(2)} ms'),
                            _buildMetricRow('Total Time', '${testTotalTime.toStringAsFixed(2)} ms'),
                            _buildMetricRow('Tokens Per Second', testTPS.toStringAsFixed(2)),
                            _buildMetricRow('Prefill Tokens', '$testPrefillTokens'),
                            _buildMetricRow('Decode Tokens', '$testDecodeTokens'),
                            _buildMetricRow('Total Tokens', '$testTotalTokens'),

                            const SizedBox(height: 16),
                            const Divider(color: Colors.black),
                            const SizedBox(height: 16),

                            // Response Section
                            const Text(
                              'Response:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              testResponse!,
                              style: const TextStyle(color: Colors.black),
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
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: DropdownMenu(
              hintText: 'Select Model',
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: availableModels.map((model) => DropdownMenuEntry(value: model.slug, label: '${model.slug} (${model.sizeMb}MB)')).toList(),
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

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }
}
