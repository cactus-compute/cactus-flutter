import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cactus/models/document.dart';
import 'package:cactus/models/rag.dart';
import 'package:cactus/objectbox.g.dart';

class CactusRAG {
  static final CactusRAG _instance = CactusRAG._internal();
  factory CactusRAG() => _instance;
  CactusRAG._internal();

  Store? _store;
  Box<Document>? _documentBox;

  Store get store {
    if (_store == null) {
      throw Exception('CactusRAG not initialized. Call initialize() first.');
    }
    return _store!;
  }

  Box<Document> get documentBox {
    if (_documentBox == null) {
      throw Exception('CactusRAG not initialized. Call initialize() first.');
    }
    return _documentBox!;
  }

  Future<void> initialize() async {
    if (_store != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _store = Store(getObjectBoxModel(), directory: p.join(docsDir.path, 'objectbox'));
    _documentBox = Box<Document>(_store!);
  }

  Future<void> close() async {
    _store?.close();
    _store = null;
    _documentBox = null;
  }

  Future<Document> storeDocument({
    required String fileName,
    required String filePath,
    required String content,
    required List<double> embeddings,
    int? fileSize,
    String? fileHash,
  }) async {
    final existingDoc = await getDocumentByFileName(fileName);
    
    if (existingDoc != null) {
      existingDoc.updateContent(content, embeddings);
      existingDoc.filePath = filePath;
      existingDoc.fileSize = fileSize;
      existingDoc.fileHash = fileHash;
      await updateDocument(existingDoc);
      return existingDoc;
    } else {
      final document = Document(
        fileName: fileName,
        filePath: filePath,
        content: content,
        embeddings: embeddings,
        fileSize: fileSize,
        fileHash: fileHash,
      );
      
      document.id = documentBox.put(document);
      return document;
    }
  }

  Future<Document?> getDocumentByFileName(String fileName) async {
    final query = documentBox.query(Document_.fileName.equals(fileName)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<List<Document>> getAllDocuments() async {
    return documentBox.getAll();
  }

  Future<void> updateDocument(Document document) async {
    documentBox.put(document);
  }

  Future<void> deleteDocument(int id) async {
    documentBox.remove(id);
  }

  Future<List<Document>> searchDocuments(String query) async {
    final allDocs = await getAllDocuments();
    return allDocs.where((doc) => 
      doc.content.toLowerCase().contains(query.toLowerCase()) ||
      doc.fileName.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  Future<List<DocumentSearchResult>> searchBySimilarity(
    List<double> queryEmbedding, {
    int limit = 10,
    double threshold = 0.5,
  }) async {
    final allDocs = await getAllDocuments();
    final results = <DocumentSearchResult>[];

    for (final doc in allDocs) {
      if (doc.embeddings.isNotEmpty) {
        final similarity = _cosineSimilarity(queryEmbedding, doc.embeddings);
        if (similarity >= threshold) {
          results.add(DocumentSearchResult(document: doc, similarity: similarity));
        }
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<DatabaseStats> getStats() async {
    final docs = await getAllDocuments();
    final totalDocs = docs.length;
    final totalContentLength = docs.fold<int>(0, (sum, doc) => sum + doc.content.length);
    final docsWithEmbeddings = docs.where((doc) => doc.embeddings.isNotEmpty).length;

    return DatabaseStats(
      totalDocuments: totalDocs,
      documentsWithEmbeddings: docsWithEmbeddings,
      totalContentLength: totalContentLength,
    );
  }
}