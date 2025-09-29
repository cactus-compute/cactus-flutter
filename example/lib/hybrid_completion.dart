import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class HybridCompletionPage extends StatefulWidget {
  const HybridCompletionPage({super.key});

  @override
  State<HybridCompletionPage> createState() => _HybridCompletionPageState();
}

class _HybridCompletionPageState extends State<HybridCompletionPage> {
  final lm = CactusLM();
  final TextEditingController _tokenController = TextEditingController();
  bool isInitializing = false;
  String outputText = 'Ready to start. Enter your Cactus token and click "Run Hybrid Completion".';
  String? lastResponse;

  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
  }

  @override
  void dispose() {
    lm.unload();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> hybridCompletionExample() async {
    if (_tokenController.text.isEmpty) {
      setState(() {
        outputText = 'Please enter your Cactus token.';
      });
      return;
    }
    
    setState(() {
      isInitializing = true;
      outputText = 'Generating response...';
    });
    
    try {
      final result = await lm.generateCompletion(
        messages: [ChatMessage(content: "What's the weather in New York?", role: "user")],
        params: CactusCompletionParams(
          completionMode: CompletionMode.hybrid
        ),
        cactusToken: _tokenController.text,
      );

      if (result.success) {
        setState(() {
          lastResponse = result.response;
          outputText = 'Generation completed successfully!';
        });
      } else {
        setState(() {
          outputText = 'Failed to generate response.';
          lastResponse = null;
        });
      }
    } catch (e) {
      setState(() {
        outputText = 'Error generating response: $e';
        lastResponse = null;
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
        title: const Text('Hybrid Completion'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Cactus Token',
                hintText: 'Enter your Cactus token here',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : hybridCompletionExample,
              child: const Text('Run Hybrid Completion Example'),
            ),

            // Status section
            if (isInitializing)
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