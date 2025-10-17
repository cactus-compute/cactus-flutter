import 'package:cactus/cactus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationMemoryService {
  static const String _summaryKey = 'conversation_summary';
  
  final CactusLM _cactusLM;
  
  ConversationMemoryService(this._cactusLM);

  Future<void> generateAndSaveSummary({
    required List<ChatMessage> currentMessages,
  }) async {
    if (currentMessages.isEmpty) {
      return;
    }

    final relevantMessages = currentMessages
        .where((m) => m.role != 'system' && m.role != 'typing')
        .toList();

    if (relevantMessages.isEmpty) {
      return;
    }

    final previousSummary = await _getPreviousSummary();

    final conversationText = relevantMessages
        .map((m) {
          final cleanedContent = _stripThinkingTags(m.content);
          return '${m.role.toUpperCase()}: $cleanedContent';
        })
        .join('\n\n');


    final summaryPrompt = _buildSummaryPrompt(
      previousSummary: previousSummary,
      conversationText: conversationText,
    );

    try {
      final result = await _cactusLM.generateCompletion(
        messages: [
          ChatMessage(
            content: summaryPrompt,
            role: 'user',
          ),
        ],
        params: CactusCompletionParams(
          maxTokens: 500
        ),
      );

      
      final cleanedSummary = _stripThinkingTags(result.response.trim());
      
      if (cleanedSummary.isNotEmpty) {
        await _saveSummary(cleanedSummary);
      } else {
      }
    } catch (e) {
      print('Error generating summary: $e');
    }
  }

  Future<String?> _getPreviousSummary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_summaryKey);
  }

  String _buildSummaryPrompt({
    String? previousSummary,
    required String conversationText,
  }) {
    if (previousSummary != null && previousSummary.isNotEmpty) {
      return '''You are tasked with creating a rolling summary of conversations. You will be given:
      1. A summary of previous conversations
      2. A new conversation that just occurred

      Your job is to create a concise, comprehensive summary that combines the previous context with the new conversation. Focus on:
      - Key topics discussed
      - Important decisions or conclusions
      - User preferences or requirements mentioned
      - Relevant context that would be useful in future conversations

      Keep the summary concise but informative (max 300 words).

      Previous Summary:
      $previousSummary

      New Conversation:
      $conversationText

      Create an updated rolling summary:''';
    } else {
      return '''You are tasked with creating a summary of a conversation. Analyze the following conversation and create a concise summary that captures:
      - Key topics discussed
      - Important decisions or conclusions
      - User preferences or requirements mentioned
      - Relevant context that would be useful in future conversations

      Keep the summary concise but informative (max 300 words).

      Conversation:
      $conversationText

      Create a summary:''';
    }
  }

  Future<void> _saveSummary(String summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_summaryKey, summary);
  }

  Future<void> clearSummary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_summaryKey);
  }

  Future<String?> getCurrentSummary() async {
    final summary = await _getPreviousSummary();
    print('getCurrentSummary called, returning: ${summary?.length ?? 0} chars');
    return summary;
  }

  String _stripThinkingTags(String content) {
    return content
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .trim();
  }

  Future<ChatMessage> getSystemMessageWithMemory() async {
    final summary = await _getPreviousSummary();
    
    if (summary != null && summary.isNotEmpty) {
      return ChatMessage(
        content: '''You are Cactus, a very capable AI assistant running offline on a smartphone.
          Previous Conversation Context:
          $summary
          Use this context to provide more personalized and contextually aware responses, but don't explicitly mention the summary unless relevant to the current conversation.''',
        role: 'system',
      );
    } else {
      return ChatMessage(
        content: 'You are Cactus, a very capable AI assistant running offline on a smartphone',
        role: 'system',
      );
    }
  }
}
