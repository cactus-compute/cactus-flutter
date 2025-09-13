# Cactus Flutter Plugin

![Cactus Logo](https://github.com/cactus-compute/cactus-flutter/blob/main/assets/logo.png)

Official Flutter plugin for Cactus, a framework for deploying LLM models locally in your app. Requires iOS 12.0+, Android API 24+.

## Resources
[![cactus](https://img.shields.io/badge/cactus-000000?logo=github&logoColor=white)](https://github.com/cactus-compute/cactus) [![HuggingFace](https://img.shields.io/badge/HuggingFace-FFD21E?logo=huggingface&logoColor=black)](https://huggingface.co/Cactus-Compute/models?sort=downloads) [![Discord](https://img.shields.io/badge/Discord-5865F2?logo=discord&logoColor=white)](https://discord.gg/bNurx3AXTJ) [![Documentation](https://img.shields.io/badge/Documentation-4285F4?logo=googledocs&logoColor=white)](https://cactuscompute.com/docs)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  cactus:
    git:
      url: https://github.com/cactus-compute/cactus-flutter.git
      ref: v1
```

Then run:
```bash
flutter pub get
```

## Getting Started

### Telemetry Setup (Optional)
```dart
import 'package:cactus/cactus.dart';

CactusTelemetry.setTelemetryToken("your-token-here");
```

## Language Model (LLM)

The `CactusLM` class provides text completion capabilities with high-performance local inference.

### Basic Usage
```dart
import 'package:cactus/cactus.dart';

Future<void> basicExample() async {
  final lm = CactusLM();

  try {
    // Download a model (default: qwen3-0.6)
    final downloadSuccess = await lm.downloadModel("qwen3-0.6");
    if (!downloadSuccess) {
      print("Failed to download model");
      return;
    }
    
    // Initialize the model
    final initSuccess = await lm.initializeModel(
      CactusInitParams(
        model: "qwen3-0.6",
        contextSize: 2048,
      ),
    );
    if (!initSuccess) {
      print("Failed to initialize model");
      return;
    }

    // Generate completion
    final result = await lm.generateCompletion(
      messages: [
        ChatMessage(content: "Hello, how are you?", role: "user"),
      ],
      params: CactusCompletionParams(
        maxTokens: 100,
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
      ),
    );

    if (result != null && result.success) {
      print("Response: ${result.response}");
      print("Tokens per second: ${result.tokensPerSecond}");
      print("Time to first token: ${result.timeToFirstTokenMs}ms");
    }
  } finally {
    // Clean up
    lm.unload();
  }
}
```

### Streaming Completions
```dart
Future<void> streamingExample() async {
  final lm = CactusLM();
  
  await lm.downloadModel("qwen3-0.6");
  await lm.initializeModel(CactusInitParams(model: "qwen3-0.6"));

  final result = await lm.generateCompletion(
    messages: [ChatMessage(content: "Tell me a story", role: "user")],
    params: CactusCompletionParams(
      maxTokens: 200,
      onToken: (token) {
        print(token); // Print each token as it's generated
        return true; // Continue generation
      },
    ),
  );

  lm.unload();
}
```

### Available Models
You can download various models by their slug identifier:
- `"qwen3-0.6"` - Default lightweight model (600MB)
- Check Cactus documentation for complete model list with sizes and capabilities

### LLM API Reference

#### CactusLM Class
- `Future<bool> downloadModel({String model = "qwen3-0.6"})` - Download a model
- `Future<bool> initializeModel(CactusInitParams params)` - Initialize model for inference
- `Future<CactusCompletionResult?> generateCompletion({required List<ChatMessage> messages, required CactusCompletionParams params})` - Generate text completion
- `void unload()` - Free model from memory
- `bool isLoaded()` - Check if model is loaded

#### Data Classes
- `CactusInitParams({String? model, int? contextSize})` - Model initialization parameters
- `CactusCompletionParams({double temperature, int topK, double topP, int maxTokens, List<String> stopSequences, int bufferSize, CactusTokenCallback? onToken})` - Completion parameters
- `ChatMessage({required String content, required String role, int? timestamp})` - Chat message format
- `CactusCompletionResult` - Contains response, timing metrics, and success status
- `CactusEmbeddingResult({required bool success, required List<double> embeddings, required int dimension, String? errorMessage})` - Embedding generation result

## Embeddings

The `CactusLM` class also provides text embedding generation capabilities for semantic similarity, search, and other NLP tasks.

### Basic Usage
```dart
import 'package:cactus/cactus.dart';

Future<void> embeddingExample() async {
  final lm = CactusLM();

  try {
    // Download and initialize a model (same as for completions)
    await lm.downloadModel("qwen3-0.6");
    await lm.initializeModel(CactusInitParams(
      model: "qwen3-0.6", 
      contextSize: 2048,
    ));

    // Generate embeddings for a text
    final result = await lm.generateEmbedding(
      text: "This is a sample text for embedding generation",
      bufferSize: 2048,
    );

    if (result != null && result.success) {
      print("Embedding dimension: ${result.dimension}");
      print("Embedding vector length: ${result.embeddings.length}");
      print("First few values: ${result.embeddings.take(5)}");
    } else {
      print("Embedding generation failed: ${result?.errorMessage}");
    }
  } finally {
    lm.unload();
  }
}
```

### Embedding API Reference

#### CactusLM Class (Embedding Methods)
- `Future<CactusEmbeddingResult?> generateEmbedding({required String text, int bufferSize = 2048})` - Generate text embeddings

#### Embedding Data Classes
- `CactusEmbeddingResult({required bool success, required List<double> embeddings, required int dimension, String? errorMessage})` - Contains the generated embedding vector and metadata

## Platform-Specific Setup

### Android
Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```


## Performance Tips

1. **Model Selection**: Choose smaller models for faster inference on mobile devices
2. **Context Size**: Reduce context size for lower memory usage (e.g., 1024 instead of 2048)
3. **Memory Management**: Always call `unload()` when done with models
4. **Batch Processing**: Reuse initialized models for multiple completions
5. **Background Processing**: Use `Isolate` for heavy operations to keep UI responsive

## Example App

Check out the example app in the `example/` directory for a complete Flutter implementation showing:
- Model downloading with progress indicators
- Text completion with streaming
- Embedding generation
- Error handling and status management
- Material Design UI integration

To run the example:
```bash
cd example
flutter pub get
flutter run
```

## Support

- 📖 [Documentation](https://cactuscompute.com/docs)
- 💬 [Discord Community](https://discord.gg/bNurx3AXTJ)
- 🐛 [Issues](https://github.com/cactus-compute/cactus-flutter/issues)
- 🤗 [Models on Hugging Face](https://huggingface.co/Cactus-Compute/models)