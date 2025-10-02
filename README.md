# Cactus Flutter Plugin

![Cactus Logo](https://github.com/cactus-compute/cactus-flutter/blob/main/assets/logo.png)

Official Flutter plugin for Cactus, a framework for deploying LLM models, speech-to-text, and RAG capabilities locally in your app. Requires iOS 12.0+, Android API 24+.

## Resources
[![cactus](https://img.shields.io/badge/cactus-000000?logo=github&logoColor=white)](https://github.com/cactus-compute/cactus) [![HuggingFace](https://img.shields.io/badge/HuggingFace-FFD21E?logo=huggingface&logoColor=black)](https://huggingface.co/Cactus-Compute/models?sort=downloads) [![Discord](https://img.shields.io/badge/Discord-5865F2?logo=discord&logoColor=white)](https://discord.gg/bNurx3AXTJ) [![Documentation](https://img.shields.io/badge/Documentation-4285F4?logo=googledocs&logoColor=white)](https://cactuscompute.com/docs)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  cactus:
    git:
      url: https://github.com/cactus-compute/cactus-flutter.git
      ref: stt
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

    if (result.success) {
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

  if (result.success) {
    print("Response: ${result.response}");
    print("Tools: ${result.toolCalls}");
  }

  lm.unload();
}
```

### Hybrid Completion (Cloud Fallback)

The `CactusLM` supports a `hybrid` completion mode that falls back to a cloud-based LLM provider (OpenRouter) if local inference fails or is not available. This ensures reliability and provides a seamless experience.

To use hybrid mode:
1.  Set `completionMode` to `CompletionMode.hybrid` in `CactusCompletionParams`.
2.  Provide an `cactusToken` to `generateCompletion` or `generateCompletionStream`.

```dart
import 'package:cactus/cactus.dart';

Future<void> hybridCompletionExample() async {
  final lm = CactusLM();
  
  // No model download or initialization needed if you only want to use cloud
  
  final result = await lm.generateCompletion(
    messages: [ChatMessage(content: "What's the weather in New York?", role: "user")],
    params: CactusCompletionParams(
      completionMode: CompletionMode.hybrid
    ),
    cactusToken: "YOUR_CACTUS_TOKEN",
  );

  if (result.success) {
    print("Response: ${result.response}");
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
- `temperature: 0.1` - Controls randomness (0.0 = deterministic, 1.0 = very random)
- `topK: 40` - Number of top tokens to consider
- `topP: 0.95` - Nucleus sampling parameter
- `maxTokens: 200` - Maximum tokens to generate
- `bufferSize: 1024` - Internal buffer size for processing
- `completionMode: CompletionMode.local` - Default to local-only inference.

### LLM API Reference

#### CactusLM Class
- `Future<void> downloadModel({String model = "qwen3-0.6", CactusProgressCallback? downloadProcessCallback})` - Download a model with optional progress callback
- `Future<void> initializeModel(CactusInitParams params)` - Initialize model for inference
- `Future<CactusCompletionResult> generateCompletion({required List<ChatMessage> messages, CactusCompletionParams? params, String? cactusToken})` - Generate text completion (uses default params if none provided)
- `Future<CactusStreamedCompletionResult> generateCompletionStream({required List<ChatMessage> messages, CactusCompletionParams? params, List<CactusTool>? tools, String? cactusToken})` - Generate streaming text completion (uses default params if none provided)
- `Future<List<CactusModel>> getModels()` - Fetch available models with caching
- `Future<CactusEmbeddingResult?> generateEmbedding({required String text, int bufferSize = 2048})` - Generate text embeddings
- `void unload()` - Free model from memory
- `bool isLoaded()` - Check if model is loaded

#### Data Classes
- `CactusInitParams({String? model, int? contextSize})` - Model initialization parameters
- `CactusCompletionParams({double temperature, int topK, double topP, int maxTokens, List<String> stopSequences, int bufferSize, List<CactusTool>? tools, CompletionMode completionMode})` - Completion parameters
- `ChatMessage({required String content, required String role, int? timestamp})` - Chat message format
- `CactusCompletionResult` - Contains response, timing metrics, and success status
- `CactusStreamedCompletionResult` - Contains the stream and the final result of a streamed completion.
- `CactusModel({required String name, required String slug, required int sizeMb, required bool supportsToolCalling, required bool supportsVision, required bool isDownloaded})` - Model information
- `CactusEmbeddingResult({required bool success, required List<double> embeddings, required int dimension, String? errorMessage})` - Embedding generation result
- `CactusTool({required String name, required String description, required Map<String, CactusToolParameter> parameters})` - Function calling tool definition
- `CactusToolParameter({required String type, required String description, required bool required})` - Tool parameter specification
- `CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError)` - Progress callback for downloads
- `CompletionMode` - Enum for completion mode (`local` or `hybrid`).

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

    if (result.success) {
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

## Speech-to-Text (STT)

The `CactusSTT` class provides high-quality local speech recognition capabilities using Vosk models. It supports multiple languages and runs entirely on-device for privacy and offline functionality.

### Basic Usage
```dart
import 'package:cactus/cactus.dart';

Future<void> sttExample() async {
  final stt = CactusSTT();

  try {
    // Download a voice model with progress callback (default: vosk-en-us)
    await stt.download(
      model: "vosk-en-us",
      downloadProcessCallback: (progress, status, isError) {
        if (isError) {
          print("Download error: $status");
        } else {
          print("$status ${progress != null ? '(${progress * 100}%)' : ''}");
        }
      },
    );
    
    // Initialize the speech recognition model
    await stt.init(model: "vosk-en-us");

    // Transcribe audio (from microphone or file)
    final result = await stt.transcribe();

    if (result != null && result.success) {
      print("Transcribed text: ${result.text}");
      print("Processing time: ${result.processingTime}ms");
    }
  } finally {
    // Clean up
    stt.dispose();
  }
}
```

### Transcribing Audio Files
```dart
Future<void> fileTranscriptionExample() async {
  final stt = CactusSTT();
  
  await stt.download();
  await stt.init();

  // Transcribe from an audio file
  final result = await stt.transcribe(
    filePath: "/path/to/audio/file.wav"
  );

  if (result != null && result.success) {
    print("File transcription: ${result.text}");
  }

  stt.dispose();
}
```

### Custom Speech Recognition Parameters
```dart
Future<void> customParametersExample() async {
  final stt = CactusSTT();
  
  await stt.download();
  await stt.init();

  // Configure custom speech recognition parameters
  final params = SpeechRecognitionParams(
    sampleRate: 16000,           // Audio sample rate (Hz)
    maxDuration: 30000,          // Maximum recording duration (ms)
    maxSilenceDuration: 3000,    // Max silence before stopping (ms)
    silenceThreshold: 300.0,     // Silence detection threshold
  );

  final result = await stt.transcribe(params: params);

  if (result != null && result.success) {
    print("Custom transcription: ${result.text}");
  }

  stt.dispose();
}
```

### Fetching Available Voice Models
```dart
Future<void> fetchVoiceModelsExample() async {
  final stt = CactusSTT();
  
  // Get list of available voice models
  final models = await stt.getVoiceModels();
  
  for (final model in models) {
    print("Model: ${model.slug}");
    print("Language: ${model.language}");
    print("Size: ${model.sizeMb} MB");
    print("Downloaded: ${model.isDownloaded}");
    print("---");
  }
}
```

### Real-time Speech Recognition Status
```dart
Future<void> realTimeStatusExample() async {
  final stt = CactusSTT();
  
  await stt.download();
  await stt.init();

  // Start transcription
  final transcriptionFuture = stt.transcribe();
  
  // Check recording status
  while (stt.isRecording) {
    print("Currently recording...");
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  // Stop recording manually if needed
  stt.stop();
  
  final result = await transcriptionFuture;
  print("Final result: ${result?.text}");

  stt.dispose();
}
```

### Default Parameters
The `CactusSTT` class uses sensible defaults for speech recognition:
- `model: "vosk-en-us"` - Default English (US) voice model
- `sampleRate: 16000` - Standard sample rate for speech recognition
- `maxDuration: 30000` - Maximum 30 seconds recording time
- `maxSilenceDuration: 2000` - Stop after 2 seconds of silence
- `silenceThreshold: 500.0` - Sensitivity for silence detection

### STT API Reference

#### CactusSTT Class
- `Future<bool> download({String model = "vosk-en-us", CactusProgressCallback? downloadProcessCallback})` - Download a voice model with optional progress callback
- `Future<bool> init({String? model})` - Initialize speech recognition model
- `Future<SpeechRecognitionResult?> transcribe({SpeechRecognitionParams? params, String? filePath})` - Transcribe speech from microphone or file
- `void stop()` - Stop current recording session
- `bool get isRecording` - Check if currently recording
- `bool isReady()` - Check if model is initialized and ready
- `Future<List<VoiceModel>> getVoiceModels()` - Fetch available voice models
- `Future<bool> isModelDownloaded([String? modelName])` - Check if a specific model is downloaded
- `void dispose()` - Clean up resources and free memory

#### STT Data Classes
- `SpeechRecognitionParams({int sampleRate = 16000, int maxDuration = 30000, int maxSilenceDuration = 2000, double silenceThreshold = 500.0})` - Speech recognition configuration
- `SpeechRecognitionResult({required bool success, required String text, double? processingTime})` - Transcription result with timing information
- `VoiceModel({required String slug, required String language, required String url, required int sizeMb, required String fileName, bool isDownloaded = false})` - Voice model information
- `CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError)` - Progress callback for model downloads

## Retrieval-Augmented Generation (RAG)

The `CactusRAG` class provides a local vector database for storing, managing, and searching documents with automatic text chunking. It uses [ObjectBox](https://objectbox.io/) for efficient on-device storage and retrieval, making it ideal for building RAG applications that run entirely locally.

**Key Features:**
- **Automatic Text Chunking**: Documents are automatically split into configurable chunks with overlap for better context preservation
- **Embedding Generation**: Integrates with `CactusLM` to automatically generate embeddings for each chunk
- **Vector Search**: Performs cosine similarity search across document chunks
- **Document Management**: Supports create, read, update, and delete operations with automatic chunk handling

### Basic Usage
```dart
import 'package:cactus/cactus.dart';

Future<void> ragExample() async {
  final lm = CactusLM();
  final rag = CactusRAG();

  try {
    // 1. Initialize LM and RAG
    await lm.downloadModel();
    await lm.initializeModel();
    await rag.initialize();

    // 2. Set up the embedding generator (uses the LM to generate embeddings)
    rag.setEmbeddingGenerator((text) async {
      final result = await lm.generateEmbedding(text: text);
      return result?.embeddings ?? [];
    });

    // 3. Configure chunking parameters (optional - defaults: chunkSize=512, chunkOverlap=64)
    rag.setChunking(chunkSize: 1024, chunkOverlap: 128);

    // 4. Store a document (automatically chunks and generates embeddings)
    final docContent = "The Eiffel Tower is a wrought-iron lattice tower on the Champ de Mars in Paris, France. It was constructed from 1887 to 1889 as the entrance arch to the 1889 World's Fair. The tower is 330 metres tall, about the same height as an 81-storey building.";
    
    final document = await rag.storeDocument(
      fileName: "eiffel_tower.txt",
      filePath: "/path/to/eiffel_tower.txt",
      content: docContent,
      fileSize: docContent.length,
      fileHash: "abc123", // Optional file hash for versioning
    );
    print("Document stored with ${document.chunks.length} chunks.");

    // 5. Search for similar content using query embeddings
    final searchResults = await rag.search(
      text: "What is the famous landmark in Paris?",
      limit: 5,
      threshold: 0.5,
    );

    print("\nFound ${searchResults.length} similar chunks:");
    for (final result in searchResults) {
      print("- Chunk from ${result.chunk.document.target?.fileName} (Similarity: ${result.similarity.toStringAsFixed(2)})");
      print("  Content: ${result.chunk.content.substring(0, 50)}...");
    }
  } finally {
    // 6. Clean up
    lm.unload();
    await rag.close();
  }
}
```

### RAG API Reference

#### CactusRAG Class
- `Future<void> initialize()` - Initialize the local ObjectBox database
- `Future<void> close()` - Close the database connection
- `void setEmbeddingGenerator(EmbeddingGenerator generator)` - Set the function used to generate embeddings for text chunks
- `void setChunking({required int chunkSize, required int chunkOverlap})` - Configure text chunking parameters (defaults: chunkSize=512, chunkOverlap=64)
- `int get chunkSize` - Get current chunk size setting
- `int get chunkOverlap` - Get current chunk overlap setting
- `List<String> chunkContent(String content, {int? chunkSize, int? chunkOverlap})` - Manually chunk text content (visible for testing)
- `Future<Document> storeDocument({required String fileName, required String filePath, required String content, int? fileSize, String? fileHash})` - Store a document with automatic chunking and embedding generation
- `Future<Document?> getDocumentByFileName(String fileName)` - Retrieve a document by its file name
- `Future<List<Document>> getAllDocuments()` - Get all stored documents
- `Future<void> updateDocument(Document document)` - Update an existing document and its chunks
- `Future<void> deleteDocument(int id)` - Delete a document and all its chunks by ID
- `Future<List<ChunkSearchResult>> search({List<double>? queryEmbedding, int limit = 10, double threshold = 0.5})` - Search for document chunks by vector similarity
- `Future<DatabaseStats> getStats()` - Get statistics about the database

#### RAG Data Classes
- `Document` - Represents a stored document with its metadata and associated chunks
- `DocumentChunk` - Represents a text chunk with its content and embeddings
- `ChunkSearchResult({required DocumentChunk chunk, required double similarity})` - Contains a document chunk and its similarity score from a search result
- `DatabaseStats` - Contains statistics about the document store including total documents, chunks, and content length
- `EmbeddingGenerator = Future<List<double>> Function(String text)` - Function type for generating embeddings from text

## Platform-Specific Setup


### Android
Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Required for speech-to-text functionality -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS
Add microphone usage description to your `ios/Runner/Info.plist` for speech-to-text functionality:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for speech-to-text transcription.</string>
```

### macOS
Add the following to your `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:
```xml
<!-- Network access for model downloads -->
<key>com.apple.security.network.client</key>
<true/>
<!-- Microphone access for speech-to-text -->
<key>com.apple.security.device.microphone</key>
<true/>
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
- Speech-to-text transcription with voice model management
- Embedding generation
- RAG document storage and search
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
