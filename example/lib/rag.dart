
import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

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
  bool isSearching = false;
  
  String outputText = 'Ready to start. Click "Download Model" to begin.';
  List<DocumentSearchResult> searchResults = [];
  DatabaseStats? dbStats;

  @override
  void initState() {
    super.initState();
    CactusTelemetry.setTelemetryToken('a83c7f7a-43ad-4823-b012-cbeb587ae788');
    _queryController.text = 'What is the famous landmark in Paris?';
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
      isInitializing = true;
      outputText = 'Initializing RAG database...';
    });
    
    try {
      await rag.initialize();
      setState(() {
        isRAGInitialized = true;
        outputText = 'RAG initialized successfully! Click "Add Sample Documents" to populate the database.';
      });
      await getDBStats();
    } catch (e) {
      setState(() {
        outputText = 'Error initializing RAG: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
      });
    }
  }

  Future<void> addSampleDocuments() async {
    if (!isModelLoaded || !isRAGInitialized) {
      setState(() {
        outputText = 'Please initialize both model and RAG first.';
      });
      return;
    }

    setState(() {
      isInitializing = true;
      outputText = 'Adding sample documents...';
    });

    try {
      // Sample documents about famous landmarks
      final documents = [
        {
          'name': 'eiffel_tower.txt',
          'content': 'The Eiffel Tower is a wrought-iron lattice tower on the Champ de Mars in Paris, France. It is named after the engineer Gustave Eiffel, whose company designed and built the tower. Constructed from 1887 to 1889, it was initially criticized by some of France\'s leading artists and intellectuals for its design, but it has become a global cultural icon of France and one of the most recognizable structures in the world.'
        },
        {
          'name': 'statue_of_liberty.txt', 
          'content': 'The Statue of Liberty is a neoclassical sculpture on Liberty Island in New York Harbor in New York City. The copper statue, a gift from the people of France to the people of the United States, was designed by French sculptor Frédéric Auguste Bartholdi and its metal framework was built by Gustave Eiffel. The statue was dedicated on October 28, 1886.'
        },
        {
          'name': 'big_ben.txt',
          'content': 'Big Ben is the nickname for the Great Bell of the Great Clock of Westminster, at the north end of the Palace of Westminster in London, England. The tower itself is officially known as Elizabeth Tower, renamed to celebrate the Diamond Jubilee of Elizabeth II in 2012. The tower was designed by Augustus Pugin in a neo-Gothic style.'
        },
        {
          'name': 'colosseum.txt',
          'content': 'The Colosseum is an oval amphitheatre in the centre of the city of Rome, Italy. Built of travertine limestone, tuff (volcanic rock), and brick-faced concrete, it was the largest amphitheatre ever built. The Colosseum is situated just east of the Roman Forum. Construction began under the emperor Vespasian in AD 72 and was completed in AD 80.'
        }
      ];

      for (final doc in documents) {
        // Generate embeddings for each document
        final embeddingResult = await lm.generateEmbedding(
          text: doc['content']!,
          bufferSize: 2048,
        );

        if (embeddingResult.success) {
          await rag.storeDocument(
            fileName: doc['name']!,
            filePath: '/sample/${doc['name']!}',
            content: doc['content']!,
            embeddings: embeddingResult.embeddings,
          );
        }
      }

      await getDBStats();
      setState(() {
        outputText = 'Sample documents added successfully! You can now search for information.';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error adding sample documents: $e';
      });
    } finally {
      setState(() {
        isInitializing = false;
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
      // Generate embeddings for the query
      final queryEmbeddingResult = await lm.generateEmbedding(
        text: _queryController.text,
        bufferSize: 2048,
      );

      if (queryEmbeddingResult.success) {
        // Search for similar documents
        final results = await rag.searchBySimilarity(
          queryEmbeddingResult.embeddings,
          limit: 5,
          threshold: 0.7
        );

        setState(() {
          searchResults = results;
          outputText = 'Found ${results.length} relevant documents!';
        });
      } else {
        setState(() {
          outputText = 'Failed to generate query embeddings.';
        });
      }
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
      isInitializing = true;
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
        isInitializing = false;
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
      print('Error getting database stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAG Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Setup buttons
            ElevatedButton(
              onPressed: isDownloading ? null : downloadModel,
              child: Text(isModelDownloaded ? 'Model Downloaded ✓' : 'Download Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeModel,
              child: Text(isModelLoaded ? 'Model Initialized ✓' : 'Initialize Model'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isInitializing ? null : initializeRAG,
              child: Text(isRAGInitialized ? 'RAG Initialized ✓' : 'Initialize RAG'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (isDownloading || isInitializing || !isModelLoaded || !isRAGInitialized) ? null : addSampleDocuments,
                    child: const Text('Add Sample Docs'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: (isDownloading || isInitializing || !isRAGInitialized) ? null : clearDatabase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const Text('Clear Data'),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Database: ${dbStats!.totalDocuments} documents',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Search section
            const Text(
              'Search Documents:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Search Query',
                hintText: 'Enter your question here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (isDownloading || isInitializing || isSearching || !isModelLoaded || !isRAGInitialized) ? null : searchDocuments,
              child: const Text('Search'),
            ),

            // Status section
            if (isDownloading || isInitializing || isSearching)
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Processing...'),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Output section
            Text(
              'Status: $outputText',
              style: TextStyle(
                color: outputText.contains('Error') ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Search results
            if (searchResults.isNotEmpty) ...[
              const Text(
                'Search Results:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final result = searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  result.document.fileName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Similarity: ${(result.similarity * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              result.document.content,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!isSearching && isRAGInitialized) ...[
              const Expanded(
                child: Center(
                  child: Text(
                    'No search results yet. Enter a query and click "Search" to find relevant documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ] else ...[
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ),
    );
  }
}
