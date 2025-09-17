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
      ref: main
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
    // Download a model with progress callback (default: qwen3-0.6)
    await lm.downloadModel(
      downloadProcessCallback: (progress, status, isError) {
        if (isError) {
          print("Download error: $status");
        } else {
          print("$status ${progress != null ? '(${progress * 100}%)' : ''}");
        }
      },
    );
    
    // Initialize the model
    await lm.initializeModel();

    // Generate completion with default parameters
    final result = await lm.generateCompletion(
      messages: [
        ChatMessage(content: "Hello, how are you?", role: "user"),
      ],
    );

    // Or with custom parameters
    final customResult = await lm.generateCompletion(
      messages: [
        ChatMessage(content: "Hello, how are you?", role: "user"),
      ],
      params: CactusCompletionParams(
        temperature: 0.7,
        maxTokens: 100,
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
  
  await lm.downloadModel();
  await lm.initializeModel();

  // Get the streaming response with default parameters
  final streamedResult = await lm.generateCompletionStream(
    messages: [ChatMessage(content: "Tell me a story", role: "user")],
  );

  // Process streaming output
  await for (final chunk in streamedResult.stream) {
    print(chunk);
  }

  // You can also get the full completion result after the stream is done
  final finalResult = await streamedResult.result;
  if (finalResult.success) {
    print("Final response: ${finalResult.response}");
    print("Tokens per second: ${finalResult.tokensPerSecond}");
  }

  lm.unload();
}
```

### Function Calling (Experimental)
```dart
Future<void> functionCallingExample() async {
  final lm = CactusLM();
  
  await lm.downloadModel();
  await lm.initializeModel();

  final tools = [
    CactusTool(
      name: "get_weather",
      description: "Get current weather for a location",
      parameters: ToolParametersSchema(
        properties: {
          'location': ToolParameter(type: 'string', description: 'City name', required: true),
        },
      ),
    ),
  ];

  final result = await lm.generateCompletion(
    messages: [ChatMessage(content: "What's the weather in New York?", role: "user")],
    params: CactusCompletionParams(
      tools: tools
    )
  );

  if (result != null && result.success) {
    print("Response: ${result.response}");
    print("Tools: ${result.toolCalls}");
  }

  lm.unload();
}
```

### Fetching Available Models
```dart
Future<void> fetchModelsExample() async {
  final lm = CactusLM();
  
  // Get list of available models with caching
  final models = await lm.getModels();
  
  for (final model in models) {
    print("Model: ${model.name}");
    print("Slug: ${model.slug}");
    print("Size: ${model.sizeMb} MB");
    print("Downloaded: ${model.isDownloaded}");
    print("Supports Tool Calling: ${model.supportsToolCalling}");
    print("Supports Vision: ${model.supportsVision}");
    print("---");
  }
}
```

### Default Parameters
The `CactusLM` class provides sensible defaults for completion parameters:
- `temperature: 0.8` - Controls randomness (0.0 = deterministic, 1.0 = very random)
- `topK: 40` - Number of top tokens to consider
- `topP: 0.95` - Nucleus sampling parameter
- `maxTokens: 1024` - Maximum tokens to generate
- `bufferSize: 1024` - Internal buffer size for processing

### LLM API Reference

#### CactusLM Class
- `Future<void> downloadModel({String model = "qwen3-0.6", CactusProgressCallback? downloadProcessCallback})` - Download a model with optional progress callback
- `Future<void> initializeModel(CactusInitParams params)` - Initialize model for inference
- `Future<CactusCompletionResult?> generateCompletion({required List<ChatMessage> messages, CactusCompletionParams? params, List<CactusTool>? tools})` - Generate text completion (uses default params if none provided)
- `Future<CactusStreamedCompletionResult> generateCompletionStream({required List<ChatMessage> messages, CactusCompletionParams? params, List<CactusTool>? tools})` - Generate streaming text completion (uses default params if none provided)
- `Future<List<CactusModel>> getModels()` - Fetch available models with caching
- `Future<CactusEmbeddingResult?> generateEmbedding({required String text, int bufferSize = 2048})` - Generate text embeddings
- `void unload()` - Free model from memory
- `bool isLoaded()` - Check if model is loaded

#### Data Classes
- `CactusInitParams({String? model, int? contextSize})` - Model initialization parameters
- `CactusCompletionParams({double temperature, int topK, double topP, int maxTokens, List<String> stopSequences, int bufferSize, List<CactusTool>? tools})` - Completion parameters
- `ChatMessage({required String content, required String role, int? timestamp})` - Chat message format
- `CactusCompletionResult` - Contains response, timing metrics, and success status
- `CactusStreamedCompletionResult` - Contains the stream and the final result of a streamed completion.
- `CactusModel({required String name, required String slug, required int sizeMb, required bool supportsToolCalling, required bool supportsVision, required bool isDownloaded})` - Model information
- `CactusEmbeddingResult({required bool success, required List<double> embeddings, required int dimension, String? errorMessage})` - Embedding generation result
- `CactusTool({required String name, required String description, required Map<String, CactusToolParameter> parameters})` - Function calling tool definition
- `CactusToolParameter({required String type, required String description, required bool required})` - Tool parameter specification
- `CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError)` - Progress callback for downloads

## Embeddings

The `CactusLM` class also provides text embedding generation capabilities for semantic similarity, search, and other NLP tasks.

### Basic Usage
```dart
import 'package:cactus/cactus.dart';

Future<void> embeddingExample() async {
  final lm = CactusLM();

  try {
    // Download and initialize a model (same as for completions)
    await lm.downloadModel();
    await lm.initializeModel();

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
6. **Model Caching**: Use `getModels()` for efficient model discovery - results are cached locally to reduce network requests

## Example App

Check out the example app in the `example/` directory for a complete Flutter implementation showing:
- Model discovery and fetching available models
- Model downloading with real-time progress indicators
- Text completion with both regular and streaming modes
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