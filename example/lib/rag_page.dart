import 'dart:async';
import 'package:cactus/models/rag.dart';
import 'package:cactus/services/rag.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:cactus/cactus.dart';

class RagPage extends StatefulWidget {
  const RagPage({super.key});

  @override
  State<RagPage> createState() => _RagPageState();
}

class _RagPageState extends State<RagPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  List<DocumentSearchResult> _lastSearchResults = [];
  final CactusLM cactusLM = CactusLM();
  final CactusRAG cactusRAG = CactusRAG();
  final bufferSize = 4096;

  @override
  void initState() {
    super.initState();
    initModel();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    cactusLM.unload();
    cactusRAG.close();
    super.dispose();
  }

  Future<void> initModel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await cactusLM.initializeModel(
        params: CactusInitParams(model: "qwen3-0.6", contextSize: 16384)
      );
      await cactusRAG.initialize();
      debugPrint('CactusLM initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize CactusLM: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize model: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() {
      _isLoading = true;
      _lastSearchResults = [];
    });

    try {
      List<double>? queryEmbedding = [];
      try {
        queryEmbedding = (await cactusLM.generateEmbedding(text: message, bufferSize: bufferSize)).embeddings;
        debugPrint('Generated query embedding: ${queryEmbedding.length} dimensions');
      } catch (e) {
        debugPrint('Failed to generate query embedding: $e');
      }

      // Search for relevant documents
      List<DocumentSearchResult> relevantDocs = [];
      if (queryEmbedding?.isNotEmpty ?? false) {
        relevantDocs = await cactusRAG.searchBySimilarity(
          queryEmbedding!,
          limit: 3,
          threshold: 0.5,
        );
        setState(() {
          _lastSearchResults = relevantDocs;
        });
        debugPrint('Found ${relevantDocs.length} relevant documents');
      }

      // Build context from relevant documents (for AI only, not shown in UI)
      String contextMessage = '';
      if (relevantDocs.isNotEmpty) {
        contextMessage = 'Based on the following document excerpts:\n\n';
        for (int i = 0; i < relevantDocs.length; i++) {
          final result = relevantDocs[i];
          final doc = result.document;
          final excerpt = doc.content;
          
          contextMessage += 'Document ${i + 1} (${doc.fileName}):\n';
          contextMessage += '$excerpt\n\n';
        }
        contextMessage += 'Question: $message\n\n';
        contextMessage += 'Please provide a helpful answer based on the document content above. If the documents don\'t contain relevant information, say so clearly.';
      } else {
        contextMessage = 'Question: $message\n\n';
      }

      // Send the context-enhanced message to the LLM (but keep original message in UI)
      await cactusLM.generateCompletion(
        messages: [ChatMessage(content: contextMessage, role: 'user')],
        params: CactusCompletionParams(maxTokens: 200, temperature: 0.3, topP: 0.9, bufferSize: bufferSize, completionMode: CompletionMode.local)
      ).timeout(
        const Duration(minutes: 5), // 5 minute timeout
        onTimeout: () {
          throw TimeoutException('The request timed out. This can happen with large images or complex queries.', const Duration(minutes: 5));
        },
      );

    } on TimeoutException catch (e) {
      debugPrint('Timeout error: $e');
      // Add timeout error message to chat
      final errorMsg = ChatMessage(role: 'assistant', content: 'The request timed out. This can happen with large images or complex processing. Please try with a smaller image or simpler query.');
      setState(() {
        _messages = [..._messages, errorMsg];
      });
    } catch (e) {
      debugPrint('Error in chat: $e');
      // Add error message to chat
      final errorMsg = ChatMessage(role: 'assistant', content: 'Sorry, I encountered an error: $e');
      setState(() {
        _messages = [..._messages, errorMsg];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            await _pickAndReadPDF();
                          },
                          icon: Icon(
                            Icons.upload_file,
                          ),
                          iconSize: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Upload your document (PDF)',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Then ask questions about it',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _MessageBubble(message: message);
                    },
                  ),
          ),

          // Show relevant documents if any
          if (_lastSearchResults.isNotEmpty)
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relevant Documents:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _lastSearchResults.length,
                      itemBuilder: (context, index) {
                        final result = _lastSearchResults[index];
                        return _DocumentChip(result: result);
                      },
                    ),
                  ),
                ],
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ) : const Icon(SolarIconsOutline.arrowRight),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        ],
      )
    );
  }

  Future<String> getPDFtext(String path) async {
    String text = "";
    try {
      text = await ReadPdfText.getPDFtext(path);
    } on PlatformException {
      debugPrint('Failed to get PDF text.');
    }
    return text;
  }

  Future<void> _pickAndReadPDF() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        String text = await getPDFtext(filePath);

        debugPrint('PDF text extracted: ${text.length} characters');

        try {
          final embedding = (await cactusLM.generateEmbedding(text: text, bufferSize: bufferSize)).embeddings;
          debugPrint('Embedding generated: ${embedding.length} dimensions');
          
          // Store document and embedding in database
          final document = await cactusRAG.storeDocument(
            fileName: fileName,
            filePath: filePath,
            content: text,
            embeddings: embedding,
            fileSize: result.files.single.size,
          );
          
          debugPrint('Document stored in database with ID: ${document.id}');
        } catch (e) {
          debugPrint('Failed to generate embedding: $e');
          
          // Still store the document without embedding
          await cactusRAG.storeDocument(
            fileName: fileName,
            filePath: filePath,
            content: text,
            embeddings: [], // Empty embedding
            fileSize: result.files.single.size,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking and reading PDF: $e');
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read PDF: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    
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
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Assistant message with thinking capability
    return _AssistantMessageBubble(message: message);
  }
}

class _AssistantMessageBubble extends StatefulWidget {
  final ChatMessage message;

  const _AssistantMessageBubble({required this.message});

  @override
  State<_AssistantMessageBubble> createState() => _AssistantMessageBubbleState();
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
    final thinkingMatch = RegExp(r'<think>(.*?)</think>', dotAll: true).firstMatch(content);
    
    if (thinkingMatch != null) {
      final thinking = thinkingMatch.group(1)?.trim() ?? '';
      final response = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
      return {
        'thinking': thinking,
        'response': _cleanContent(response),
      };
    }
    
    return {
      'thinking': '',
      'response': _cleanContent(content),
    };
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
                                    SolarIconsOutline.lightbulb,
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
                                    _showThinking ? Icons.expand_less : Icons.expand_more,
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
                    ],
                  )
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  final DocumentSearchResult result;

  const _DocumentChip({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 14, color: Colors.red.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  result.document.fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Similarity: ${(result.similarity * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
