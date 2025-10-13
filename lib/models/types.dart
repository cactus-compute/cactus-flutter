import 'tools.dart';

typedef CactusTokenCallback = bool Function(String token);
typedef CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError);

class ChatMessage {
  final String content;
  final String role;
  final int? timestamp;

  ChatMessage({
    required this.content,
    required this.role,
    this.timestamp,
  });

  @override
  bool operator ==(Object other) => other is ChatMessage && role == other.role && content == other.content;
  
  @override
  int get hashCode => role.hashCode ^ content.hashCode;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (timestamp != null) 'timestamp': timestamp,
  };
}

class CactusCompletionParams {
  final double temperature;
  final int topK;
  final double topP;
  final int maxTokens;
  final List<String> stopSequences;
  final List<CactusTool>? tools;
  final CompletionMode completionMode;

  CactusCompletionParams({
    this.temperature = 0.1,
    this.topK = 40,
    this.topP = 0.95,
    this.maxTokens = 200,
    this.stopSequences = const ["<|im_end|>", "<end_of_turn>"],
    this.tools,
    this.completionMode = CompletionMode.local,
  });
}

class CactusCompletionResult {
  final bool success;
  final String response;
  final double timeToFirstTokenMs;
  final double totalTimeMs;
  final double tokensPerSecond;
  final int prefillTokens;
  final int decodeTokens;
  final int totalTokens;
  final List<ToolCall> toolCalls;

  CactusCompletionResult({
    required this.success,
    required this.response,
    required this.timeToFirstTokenMs,
    required this.totalTimeMs,
    required this.tokensPerSecond,
    required this.prefillTokens,
    required this.decodeTokens,
    required this.totalTokens,
    this.toolCalls = const [],
  });
}

class CactusException implements Exception {
  final String message;
  final dynamic underlyingError;

  CactusException(this.message, [this.underlyingError]);

  @override
  String toString() {
    if (underlyingError != null) {
      return 'CactusException: $message (Caused by: $underlyingError)';
    }
    return 'CactusException: $message';
  }
}

class CactusInitParams {
  String model;
  final int? contextSize;

  CactusInitParams({
    required this.model,
    this.contextSize,
  });
}

class CactusStreamedCompletionResult {
  final Stream<String> stream;
  final Future<CactusCompletionResult> result;

  CactusStreamedCompletionResult({required this.stream, required this.result});
}

class CactusEmbeddingResult {
  final bool success;
  final List<double> embeddings;
  final int dimension;
  final String? errorMessage;

  CactusEmbeddingResult({
    required this.success,
    required this.embeddings,
    required this.dimension,
    this.errorMessage,
  });
}

class CactusModel {
  final DateTime createdAt;
  final String slug;
  final String downloadUrl;
  final int sizeMb;
  final bool supportsToolCalling;
  final bool supportsVision;
  final String name;
  bool isDownloaded;

  CactusModel({
    required this.createdAt,
    required this.slug,
    required this.downloadUrl,
    required this.sizeMb,
    required this.supportsToolCalling,
    required this.supportsVision,
    required this.name,
    this.isDownloaded = false,
  });

  factory CactusModel.fromJson(Map<String, dynamic> json) {
    return CactusModel(
      createdAt: DateTime.parse(json['created_at'] as String),
      slug: json['slug'] as String,
      sizeMb: json['size_mb'] as int,
      downloadUrl: json['download_url'] as String,
      supportsToolCalling: json['supports_tool_calling'] as bool,
      supportsVision: json['supports_vision'] as bool,
      name: json['name'] as String,
      isDownloaded: false,
    );
  }
}

enum CompletionMode {
  local,
  hybrid
}

enum TranscriptionProvider {
  vosk,
  whisper
}

class VoiceModel {
  final DateTime createdAt;
  final String slug;
  final String language;
  final String url;
  final int sizeMb;
  final String fileName;
  bool isDownloaded;

  VoiceModel({
    required this.createdAt,
    required this.slug,
    required this.language,
    required this.url,
    required this.sizeMb,
    required this.fileName,
    this.isDownloaded = false,
  });

  factory VoiceModel.fromJson(Map<String, dynamic> json) {
    return VoiceModel(
      createdAt: DateTime.parse(json['created_at'] as String),
      slug: json['slug'] as String,
      language: json['language'] as String,
      url: json['url'] as String,
      sizeMb: _parseIntFromDynamic(json['size_mb']),
      fileName: json['file_name'] as String,
      isDownloaded: false,
    );
  }

  static int _parseIntFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Cannot parse $value as int');
  }
}

class SpeechRecognitionParams {
  final int sampleRate;
  final int maxDuration;
  final int maxSilenceDuration;
  final double silenceThreshold;

  SpeechRecognitionParams({
    this.sampleRate = 16000,
    this.maxDuration = 30000,
    this.maxSilenceDuration = 2000,
    this.silenceThreshold = 500.0,
  });
}

class SpeechRecognitionResult {
  final bool success;
  final String text;
  final double? processingTime;

  SpeechRecognitionResult({
    required this.success,
    required this.text,
    this.processingTime
  });
}

class STTInitParams {
  final String model;

  STTInitParams({
    required this.model,
  });
}