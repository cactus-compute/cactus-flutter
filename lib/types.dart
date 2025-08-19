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
  final int bufferSize;

  CactusCompletionParams({
    this.temperature = 0.8,
    this.topK = 40,
    this.topP = 0.95,
    this.maxTokens = 1024,
    this.stopSequences = const [],
    this.bufferSize = 1024,
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

  CactusCompletionResult({
    required this.success,
    required this.response,
    required this.timeToFirstTokenMs,
    required this.totalTimeMs,
    required this.tokensPerSecond,
    required this.prefillTokens,
    required this.decodeTokens,
    required this.totalTokens,
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