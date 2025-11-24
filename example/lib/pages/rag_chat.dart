import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

// Import our custom widgets
import '../widgets/message_bubble.dart' show AppMessage, MessageBubble;
import '../widgets/input_area.dart' show InputArea;
import '../widgets/document_preview.dart';

/// Main RAG Chat Page
class RAGChatPage extends StatefulWidget {
  const RAGChatPage({super.key});

  @override
  State<RAGChatPage> createState() => _RAGChatPageState();
}

class _RAGChatPageState extends State<RAGChatPage> {
  // Cactus components
  final _embeddingModel = CactusLM();
  final _chatModel = CactusLM();
  final _rag = CactusRAG();

  // Controllers
  final _messageController = TextEditingController();

  /// Strip thinking process tags from model output
  String _stripThinkingTags(String text) {
    // Remove content within <think>...</think> tags (case-insensitive)
    final regex =
        RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true);
    return text.replaceAll(regex, '').trim();
  }

  // State flags
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isProcessing = false;

  // Data storage
  final List<AppMessage> _messages = [];

  // Document state
  List<Document> _documents = [];
  bool _isAddingDocument = false;
  List<Map<String, dynamic>> _pendingDocs = [];

  // Track if we're using RAG mode or describe mode
  bool get _hasQuery => _messageController.text.trim().isNotEmpty;
  bool get _hasPendingDocs => _pendingDocs.isNotEmpty;

  // Status tracking
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
    _initializeSystem();
  }

  @override
  void dispose() {
    _embeddingModel.unload();
    _chatModel.unload();
    _rag.close();
    _messageController.dispose();
    super.dispose();
  }

  /// Initialize the entire RAG system
  Future<void> _initializeSystem() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = 'Downloading embedding model...';
    });

    try {
      // Step 1: Download and initialize embedding model
      await _embeddingModel.downloadModel(
        model: 'qwen3-0.6-embed',
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            _statusMessage = isError ? 'Error: $status' : status;
          });
        },
      );

      setState(() => _statusMessage = 'Initializing embedding model...');
      await _embeddingModel.initializeModel(
        params: CactusInitParams(model: 'qwen3-0.6-embed'),
      );

      // Step 2: Download and initialize chat model (Qwen 3 - 600M)
      setState(() => _statusMessage = 'Downloading chat model...');
      await _chatModel.downloadModel(
        model: 'qwen3-0.6',
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            _statusMessage = isError ? 'Error: $status' : status;
          });
        },
      );

      setState(() => _statusMessage = 'Initializing chat model...');
      await _chatModel.initializeModel(
        params: CactusInitParams(model: 'qwen3-0.6'),
      );

      // Step 3: Initialize RAG database
      setState(() => _statusMessage = 'Setting up vector database...');
      await _rag.initialize();
      _rag.setEmbeddingGenerator((text) async {
        final result = await _embeddingModel.generateEmbedding(text: text);
        return result.embeddings;
      });
      _rag.setChunking(chunkSize: 1024, chunkOverlap: 128);

      // Step 4: Mark as ready
      setState(() {
        _isInitializing = false;
        _isReady = true;
        _statusMessage = 'System ready!';
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  /// Add a document (txt, md, or pdf)
  Future<void> _addDocument() async {
    try {
      setState(() => _isAddingDocument = true);
      // Pending documents (uploaded but not yet described)

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'pdf'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isAddingDocument = false);
        return;
      }

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      final fileSize = result.files.single.size;
      final extension = fileName.split('.').last.toLowerCase();

      String content;

      // Extract text based on file type
      if (extension == 'pdf') {
        content = await ReadPdfText.getPDFtext(filePath);
      } else {
        // For .txt and .md files
        content = await File(filePath).readAsString();
      }

      if (content.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty or could not be read')),
          );
        }
        return;
      }

      // // Store document in RAG database - Might need to be done when sent button is clicked
      // await _rag.storeDocument(
      //   fileName: fileName,
      //   filePath: filePath,
      //   content: content,
      //   fileSize: fileSize,
      // );

      // Add to pending docs list (in-chat attachment)
      setState(() {
        _pendingDocs.add({
          'fileName': fileName,
          'fileSize': fileSize,
          'content': content,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: $fileName')),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding document: $e')),
        );
      }
    } finally {
      setState(() => _isAddingDocument = false);
    }
  }

  /// Remove a pending document
  void _removePendingDoc(int index) {
    setState(() {
      _pendingDocs.removeAt(index);
    });
  }

  /// Smart send: RAG search if query exists, auto-describe if only docs
  Future<void> _sendMessage() async {
    if (!_hasQuery && !_hasPendingDocs) return;

    final userQuery = _messageController.text.trim();
    final docsToProcess = List<Map<String, dynamic>>.from(_pendingDocs);

    // Clear input and pending
    _messageController.clear();
    setState(() {
      _pendingDocs.clear();
      _isProcessing = true;
    });

    try {
      if (_hasQuery && docsToProcess.isNotEmpty) {
        // Mode 1: RAG search with query + docs
        await _ragSearchWithDocs(userQuery, docsToProcess);
      } else if (_hasQuery) {
        // Mode 2: Just query (no docs)
        await _simpleQuery(userQuery);
      } else {
        // Mode 3: Auto-describe docs (no query)
        await _autoDescribeDocs(docsToProcess);
      }
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error: $e',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Mode 1: RAG search with documents
  Future<void> _ragSearchWithDocs(
      String query, List<Map<String, dynamic>> docs) async {
    // Add user message
    setState(() {
      _messages.add(AppMessage(text: query, isUser: true));
    });

    try {
      // Store documents first
      for (final doc in docs) {
        await _rag.storeDocument(
          fileName: doc['fileName'],
          filePath: '', // Not needed for content-based storage
          content: doc['content'],
          fileSize: doc['fileSize'],
        );
      }

      // Search RAG database
      final results = await _rag.search(text: query, limit: 3);

      // Build context from results - limit context size
      final contextChunks = results.map((r) => r.chunk.content).toList();
      var context = contextChunks.join('\n\n');

      // Truncate if context is too long (keep it under ~800 tokens ~3200 chars)
      if (context.length > 3000) {
        context = context.substring(0, 3000) + '...';
      }

      // Generate response with context
      final response = await _chatModel.generateCompletion(
        messages: [
          ChatMessage(
              content:
                  'You are a helpful assistant. Answer questions based on the provided context.',
              role: 'system'),
          ChatMessage(
              content: 'Context:\n$context\n\nQuestion: $query', role: 'user'),
        ],
        params: CactusCompletionParams(
          maxTokens: 400,
          temperature: 0.7,
          stopSequences: [],
        ),
      );

      if (!response.success) {
        setState(() {
          _messages.add(AppMessage(
            text:
                'Failed to generate response. Try with a shorter query or document.',
            isUser: false,
          ));
        });
        return;
      }

      setState(() {
        _messages.add(AppMessage(
          text: _stripThinkingTags(response.response),
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error: $e',
          isUser: false,
        ));
      });
    }
  }

  /// Mode 3: Auto-describe documents
  Future<void> _autoDescribeDocs(List<Map<String, dynamic>> docs) async {
    try {
      // Store documents
      for (final doc in docs) {
        await _rag.storeDocument(
          fileName: doc['fileName'],
          filePath: '',
          content: doc['content'],
          fileSize: doc['fileSize'],
        );
      }

      // Generate description
      final docNames = docs.map((d) => d['fileName']).join(', ');

      // Limit document content length to avoid context overflow
      var docContents = docs
          .map((d) => '${d['fileName']}:\n${d['content']}')
          .join('\n\n---\n\n');

      // Truncate if too long (keep under ~1000 chars for summary)
      if (docContents.length > 1500) {
        docContents = docContents.substring(0, 1500) + '\n...[truncated]';
      }

      final response = await _chatModel.generateCompletion(
        messages: [
          ChatMessage(
              content: 'You are a helpful assistant that summarizes documents.',
              role: 'system'),
          ChatMessage(
              content:
                  'Provide a brief summary of this document:\n\n$docContents',
              role: 'user'),
        ],
        params: CactusCompletionParams(
          maxTokens: 400,
          temperature: 0.7,
          stopSequences: [],
        ),
      );

      if (!response.success) {
        setState(() {
          _messages.add(AppMessage(
            text:
                'Documents added: $docNames\n\nFailed to generate summary. The document may be too large.',
            isUser: false,
          ));
        });
        return;
      }

      setState(() {
        _messages.add(AppMessage(
          text:
              'Documents added: $docNames\n\n${_stripThinkingTags(response.response)}',
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error: $e',
          isUser: false,
        ));
      });
    }
  }

  /// Mode 2: Simple query without documents
  /// Simple query without documents
  Future<void> _simpleQuery(String query) async {
    // Add user message
    setState(() {
      _messages.add(AppMessage(text: query, isUser: true));
    });

    try {
      // Get LLM response
      final response = await _chatModel.generateCompletion(
        messages: [
          ChatMessage(
              content: 'You are Cactus, a helpful AI assistant.',
              role: 'system'),
          ChatMessage(content: query, role: 'user'),
        ],
        params: CactusCompletionParams(
          maxTokens: 400,
          temperature: 0.7,
          stopSequences: [],
        ),
      );

      if (!response.success) {
        setState(() {
          _messages.add(AppMessage(
            text: 'Failed to generate response. Please try again.',
            isUser: false,
          ));
        });
        return;
      }

      // Add AI response
      setState(() {
        _messages.add(AppMessage(
          text: _stripThinkingTags(response.response),
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error: $e',
          isUser: false,
        ));
      });
    }
  }
  
  /// Mode 3: Auto-describe uploaded documents
  Future<void> _autoDescribe(List<Map<String, dynamic>> docs) async {
    // Add user message showing what was uploaded
    final fileNames = docs.map((d) => d['fileName'] as String).join(', ');
    setState(() {
      _messages.add(AppMessage(
        text: 'Uploaded: $fileNames',
        isUser: true,
      ));
    });
    
    try {
      // Combine all document content
      final combinedContent = docs.map((d) => d['content'] as String).join('\n\n---\n\n');
      
      // Create summary prompt
      final prompt = '''I have uploaded ${docs.length} document(s). Please provide a brief summary of what these documents contain (2-3 sentences):

$combinedContent

Summary:''';
      
      // Get LLM response
      final response = await _chatModel.generateCompletion(
        messages: [
          ChatMessage(content: prompt, role: 'user'),
        ],
      );
      
      // Add AI response
      setState(() {
        _messages.add(AppMessage(
          text: response.response,
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error describing documents: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _ragSearch(String query, List<Map<String, dynamic>> docs) async {
    // Add user message
    final fileNames = docs.map((d) => d['fileName'] as String).join(', ');
    setState(() {
      _messages.add(AppMessage(
        text: '$query\n\nDocuments: $fileNames',
        isUser: true,
      ));
    });
    
    try {
      // Step 1: Embed and store documents NOW (not during upload)
      for (var doc in docs) {
        await _rag.storeDocument(
          fileName: doc['fileName'],
          filePath: '', // Not needed for search
          content: doc['content'],
          fileSize: doc['fileSize'],
        );
      }
      
      // Step 2: Search for relevant context
      final searchResults = await _rag.search(
        text: query,
        limit: 3,
      );
      
      // Step 3: Build context from search results
      String context = '';
      if (searchResults.isNotEmpty) {
        context = 'Relevant information from documents:\n\n';
        for (var result in searchResults) {
          final docName = result.chunk.document.target?.fileName ?? 'Unknown';
          context += '[$docName]: ${result.chunk.content}\n\n';
        }
      }
      
      // Step 4: Build prompt with context
      final prompt = context.isEmpty 
          ? query 
          : '''$context

Based on the information above, please answer this question:
$query''';
      
      // Step 5: Get LLM response
      final response = await _chatModel.generateCompletion(
        messages: [
          ChatMessage(content: prompt, role: 'user'),
        ],
      );
      
      // Add AI response
      setState(() {
        _messages.add(AppMessage(
          text: response.response,
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(AppMessage(
          text: 'Error: $e',
          isUser: false,
        ));
      });
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile RAG'),
        actions: [
          if (_isReady)
            IconButton(
              icon: _isAddingDocument
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add),
              onPressed: _isAddingDocument ? null : _addDocument,
              tooltip: 'Add Document',
            ),
        ],
      ),
      body: _isInitializing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Chat messages area
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'Upload a document to start',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return MessageBubble(message: message);
                          },
                        ),
                ),
                DocumentPreview(
                  pendingDocs: _pendingDocs,
                  onRemove: _removePendingDoc,
                ),
                // Input area with add document button
                InputArea(
                  isAddingDocument: _isAddingDocument,
                  isProcessing: _isProcessing,
                  onAddDocument: _addDocument,
                  onSend: _sendMessage,
                  messageController: _messageController,
                  canSend: _hasQuery || _hasPendingDocs,
                ),
              ],
            ),
    );
  }
}
