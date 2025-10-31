import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class ChatMessageWithMetrics {
  final ChatMessage message;
  final CactusCompletionResult? metrics;

  ChatMessageWithMetrics({
    required this.message,
    this.metrics,
  });
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final cactusLM = CactusLM();
  final List<ChatMessageWithMetrics> chatMessages = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupCactusLM();
  }

  @override
  void dispose() {
    cactusLM.unload();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return Future.value();

    setState(() {
      chatMessages.add(ChatMessageWithMetrics(
        message: ChatMessage(content: message, role: 'user'),
      ));
      chatMessages.add(ChatMessageWithMetrics(
        message: ChatMessage(content: '', role: 'typing'),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    await _llmCall();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _llmCall() async {
    final messagesToPass = chatMessages
        .where((m) => m.message.role != 'typing')
        .map((m) => m.message)
        .toList();
    debugPrint("Messages to pass: ${messagesToPass.map((m) => "[${m.role}] ${m.content}").join(", ")}");
    
    final CactusStreamedCompletionResult res = await cactusLM.generateCompletionStream(
      messages: messagesToPass
    );

    await for (final chunk in res.stream) {
      setState(() {
        // Remove typing indicator if it exists
        if (chatMessages.isNotEmpty && chatMessages.last.message.role == 'typing') {
          chatMessages.removeLast();
        }
        
        if (chatMessages.isNotEmpty &&
            chatMessages.last.message.role == 'assistant') {
          chatMessages[chatMessages.length - 1] = ChatMessageWithMetrics(
            message: ChatMessage(
              content: chatMessages.last.message.content + chunk,
              role: 'assistant',
            ),
          );
        } else {
          chatMessages.add(ChatMessageWithMetrics(
            message: ChatMessage(content: chunk, role: 'assistant'),
          ));
        }
      });
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    final result = await res.result;
    
    // Update the last assistant message with metrics
    setState(() {
      if (chatMessages.isNotEmpty && chatMessages.last.message.role == 'assistant') {
        chatMessages[chatMessages.length - 1] = ChatMessageWithMetrics(
          message: chatMessages.last.message,
          metrics: result,
        );
      }
    });
  }

  Future<void> _setupCactusLM() async {
    await cactusLM.downloadModel();
    await cactusLM.initializeModel(params: CactusInitParams(model: "qwen3-0.6", contextSize: 4096));
    cactusLM.generateCompletionStream(
      messages: [ChatMessage(content: 'You are Cactus, a very capable AI assistant running offline on a smartphone', role: "system")],
      params: CactusCompletionParams(
        maxTokens: 0
      )
    );
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                chatMessages.clear();
              });
            },
            tooltip: 'Clear conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: chatMessages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final messageWithMetrics = chatMessages[index];
                      return _MessageBubble(
                        message: messageWithMetrics.message,
                        result: messageWithMetrics.metrics,
                      );
                    },
                  ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ask anything...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoading ? null : sendMessage,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.arrow_circle_right,
                              color: Colors.black,
                              size: 40,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final CactusCompletionResult? result;

  const _MessageBubble({required this.message, this.result});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTyping = message.role == 'typing';

    if (isUser) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(left: 50),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isTyping) {
      return _TypingIndicator();
    }

    return _AssistantMessageBubble(message: message, result: result);
  }
}

class _AssistantMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final CactusCompletionResult? result;

  const _AssistantMessageBubble({required this.message, this.result});

  @override
  State<_AssistantMessageBubble> createState() =>
      _AssistantMessageBubbleState();
}

class _AssistantMessageBubbleState extends State<_AssistantMessageBubble> {
  bool _showThinking = false;

  String _cleanContent(String content) {
    // Remove <|im_end|> and similar end tokens
    String cleaned = content
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();

    return cleaned;
  }

  Map<String, String> _parseThinkingContent(String content) {
    final thinkingMatch = RegExp(
      r'<think>(.*?)</think>',
      dotAll: true,
    ).firstMatch(content);

    if (thinkingMatch != null) {
      final thinking = thinkingMatch.group(1)?.trim() ?? '';
      final response = content
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();
      return {'thinking': thinking, 'response': _cleanContent(response)};
    }

    return {'thinking': '', 'response': _cleanContent(content)};
  }

  @override
  Widget build(BuildContext context) {
    final parsedContent = _parseThinkingContent(widget.message.content);
    final hasThinking = parsedContent['thinking']!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thinking section (collapsible)
                if (hasThinking) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _showThinking = !_showThinking;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thinking...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _showThinking
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              if (_showThinking) ...[
                                const SizedBox(height: 8),
                                Text(
                                  parsedContent['thinking']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Main response
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsedContent['response']!,
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (widget.result?.tokensPerSecond != null)
                        Text(
                          "Tokens: ${widget.result?.totalTokens ?? 0} • TTFT: ${widget.result?.timeToFirstTokenMs ?? 0} ms • ${widget.result?.tokensPerSecond.toStringAsFixed(1) ?? 0} tok/sec",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final value = (_controller.value - delay) % 1.0;
                    final scale = value < 0.5
                        ? 1.0 + (value * 0.6)
                        : 1.3 - ((value - 0.5) * 0.6);
                    
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
