
import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

class RAGPage extends StatefulWidget {
  const RAGPage({super.key});

  @override
  State<RAGPage> createState() => _RAGPageState();
}

class _RAGPageState extends State<RAGPage> {
  final lm = CactusLM();
  final rag = CactusRAG();
  final TextEditingController _queryController = TextEditingController();
  
  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isRAGInitialized = false;
  bool isDownloading = false;
  bool isInitializing = false;
  bool isInitializingRAG = false;
  bool isAddingDocuments = false;
  bool isSearching = false;
  bool isClearingDatabase = false;
  
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  List<ChunkSearchResult> searchResults = [];
  DatabaseStats? dbStats;

  @override
  void initState() {
    super.initState();
    _queryController.text = '';
  }

  @override
  void dispose() {
    lm.unload();
    rag.close();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> downloadModel() async {
    setState(() {
      isDownloading = true;
      outputText = 'Downloading model...';
    });
    
    try {
      await lm.downloadModel(
        model: 'qwen3-0.6-embed',
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            if (isError) {
              outputText = 'Error: $status';
            } else {
              outputText = status;
              if (progress != null) {
                outputText += ' (${(progress * 100).toStringAsFixed(1)}%)';
              }
            }
          });
        },
      );
      setState(() {
        isModelDownloaded = true;
        outputText = 'Model downloaded successfully! Click "Initialize Model" to load it.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error downloading model: $e';
      });
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> initializeModel() async {
    setState(() {
      isInitializing = true;
      outputText = 'Initializing model...';
    });
    
    try {
      await lm.initializeModel(params: CactusInitParams(model: 'qwen3-0.6-embed'));
      setState(() {
        isModelLoaded = true;
        outputText = 'Model initialized successfully! Click "Initialize RAG" to set up the database.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error initializing model: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> initializeRAG() async {
    setState(() {
      isInitializingRAG = true;
      outputText = 'Initializing RAG database...';
    });
    
    try {
      await rag.initialize();
      rag.setEmbeddingGenerator((text) async {
        final result = await lm.generateEmbedding(text: text);
        return result.embeddings;
      });
      rag.setChunking(chunkSize: 500, chunkOverlap: 50);
      setState(() {
        isRAGInitialized = true;
        outputText = 'RAG initialized successfully! Click "Add Docs" to populate the database.';
      });
      await getDBStats();
    } catch (e) {
      setState(() {
        outputText = 'Error initializing RAG: $e';
      });
    } finally {
      setState(() {
        isInitializingRAG = false;
      });
    }
  }

  Future<String> _getPDFtext(String path) async {
    String text = "";
    try {
      text = await ReadPdfText.getPDFtext(path);
    } on PlatformException {
      debugPrint('Failed to get PDF text.');
    }
    return text;
  }

  Future<void> addDocument() async {
    try {
      setState(() {
        isAddingDocuments = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        String text = await _getPDFtext(filePath);

        debugPrint('PDF text extracted: ${text.length} characters');

        try {
          final document = await rag.storeDocument(
            fileName: fileName,
            filePath: filePath,
            content: text,
            fileSize: result.files.single.size,
          );
          
          debugPrint('Document stored in database with ID: ${document.id}');
        } catch (e) {
          debugPrint('Failed to store document: $e');
        }
      }
    } catch (e) {
      debugPrint('Error picking and reading PDF: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read PDF: $e')),
        );
      }
    } finally {
      await getDBStats();
      setState(() {
        isAddingDocuments = false;
      });
    }
  }

  Future<void> searchDocuments() async {
    if (!isModelLoaded || !isRAGInitialized) {
      setState(() {
        outputText = 'Please initialize both model and RAG first.';
      });
      return;
    }

    if (_queryController.text.isEmpty) {
      setState(() {
        outputText = 'Please enter a search query.';
      });
      return;
    }

    setState(() {
      isSearching = true;
      outputText = 'Searching documents...';
      searchResults = [];
    });

    try {
      final results = await rag.search(
        text: _queryController.text,
        limit: 2
      );

      setState(() {
        searchResults = results;
        outputText = 'Found ${results.length} relevant chunks!';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error searching documents: $e';
      });
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  Future<void> clearDatabase() async {
    if (!isRAGInitialized) {
      setState(() {
        outputText = 'Please initialize RAG first.';
      });
      return;
    }

    setState(() {
      isClearingDatabase = true;
      outputText = 'Clearing database...';
    });

    try {
      final allDocs = await rag.getAllDocuments();
      for (final doc in allDocs) {
        await rag.deleteDocument(doc.id);
      }
      
      await getDBStats();
      setState(() {
        searchResults = [];
        outputText = 'Database cleared successfully!';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error clearing database: $e';
      });
    } finally {
      setState(() {
        isClearingDatabase = false;
      });
    }
  }

  Future<void> getDBStats() async {
    try {
      final stats = await rag.getStats();
      setState(() {
        dbStats = stats;
      });
    } catch (e) {
      debugPrint('Error getting database stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('RAG'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "RAG (Retrieval-Augmented Generation) Demo",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This example demonstrates how to store PDF documents, convert them to searchable embeddings, and perform semantic search to find relevant content based on your queries.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Setup buttons
            ElevatedButton(
              onPressed: isDownloading ? null : downloadModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isDownloading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Downloading...'),
                    ],
                  )
                : Text(isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isInitializing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Initializing...'),
                    ],
                  )
                : Text(isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializingRAG ? null : initializeRAG,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isInitializingRAG
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Initializing RAG...'),
                    ],
                  )
                : Text(isRAGInitialized ? 'RAG Initialized ✓' : 'Initialize RAG'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (isDownloading || isInitializing || isInitializingRAG || isAddingDocuments || !isModelLoaded || !isRAGInitialized) ? null : addDocument,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: isAddingDocuments
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Adding...'),
                          ],
                        )
                      : const Text('Add Docs'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: (isDownloading || isInitializing || isInitializingRAG || isClearingDatabase || !isRAGInitialized) ? null : clearDatabase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: isClearingDatabase
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Clearing...'),
                          ],
                        )
                      : const Text('Clear Data'),
                  ),
                ),
              ],
            ),

            // Database stats
            if (dbStats != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Database: ${dbStats!.totalDocuments} documents',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Search section
            const Text(
              'Search Documents:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _queryController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Search Query',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Enter your question here...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isDownloading || isInitializing || isInitializingRAG || isSearching || !isModelLoaded || !isRAGInitialized) ? null : searchDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: isSearching
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Searching...'),
                    ],
                  )
                : const Text('Search'),
            ),

            const SizedBox(height: 20),

            // Output section
            Text(
              'Status: $outputText',
              style: TextStyle(
                color: outputText.contains('Error') ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Search results
            if (searchResults.isNotEmpty) ...[
              const Text(
                'Search Results:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  result.chunk.document.target?.fileName ?? 'Unknown Document',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.chunk.content,
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ] else if (!isSearching && isRAGInitialized) ...[
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'No search results yet. Enter a query and click "Search" to find relevant documents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
