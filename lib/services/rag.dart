import 'dart:math';
import 'package:cactus/services/telemetry.dart';
import 'package:cactus/src/services/api/telemetry.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cactus/models/document.dart';
import 'package:cactus/models/rag.dart';
import 'package:cactus/objectbox.g.dart';

typedef EmbeddingGenerator = Future<List<double>> Function(String text);

class CactusRAG {
  static final CactusRAG _instance = CactusRAG._internal();
  factory CactusRAG() => _instance;
  CactusRAG._internal();

  Store? _store;
  Box<Document>? _documentBox;
  Box<DocumentChunk>? _chunkBox;
  EmbeddingGenerator? _embeddingGenerator;
  int _chunkSize = 512;
  int _chunkOverlap = 64;

  int get chunkSize => _chunkSize;
  int get chunkOverlap => _chunkOverlap;

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

  Box<DocumentChunk> get chunkBox {
    if (_chunkBox == null) {
      throw Exception('CactusRAG not initialized. Call initialize() first.');
    }
    return _chunkBox!;
  }

  void setEmbeddingGenerator(EmbeddingGenerator generator) {
    _embeddingGenerator = generator;
  }

  void setChunking({required int chunkSize, required int chunkOverlap}) {
    _validateChunkingParams(chunkSize, chunkOverlap);
    _chunkSize = chunkSize;
    _chunkOverlap = chunkOverlap;
  }

  Future<void> initialize() async {
    if (!Telemetry.isInitialized) {
      await Telemetry.init(CactusTelemetry.telemetryToken);
    }
    if (_store != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _store = Store(getObjectBoxModel(), directory: p.join(docsDir.path, 'objectbox'));
    _documentBox = Box<Document>(_store!);
    _chunkBox = Box<DocumentChunk>(_store!);
  }

  Future<void> close() async {
    _store?.close();
    _store = null;
    _documentBox = null;
    _chunkBox = null;
  }

  @visibleForTesting
  List<String> chunkContent(
    String content, {
    int? chunkSize,
    int? chunkOverlap,
  }) {
    final resolvedChunkSize = chunkSize ?? _chunkSize;
    final resolvedChunkOverlap = chunkOverlap ?? _chunkOverlap;
    return _chunkContent(
      content,
      chunkSize: resolvedChunkSize,
      chunkOverlap: resolvedChunkOverlap,
    );
  }

  List<String> _chunkContent(String content, {required int chunkSize, required int chunkOverlap}) {
    _validateChunkingParams(chunkSize, chunkOverlap);

    if (content.isEmpty) return const [];

    final step = chunkSize - chunkOverlap;
    final chunks = <String>[];

    for (var i = 0; i < content.length; i += step) {
      final end = min(i + chunkSize, content.length);
      chunks.add(content.substring(i, end));
      if (end >= content.length) {
        break;
      }
    }
    return chunks;
  }

  void _validateChunkingParams(int chunkSize, int chunkOverlap) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'chunkSize must be greater than 0.');
    }
    if (chunkOverlap < 0) {
      throw ArgumentError.value(chunkOverlap, 'chunkOverlap', 'chunkOverlap cannot be negative.');
    }
    if (chunkOverlap >= chunkSize) {
      throw ArgumentError(
        'chunkOverlap ($chunkOverlap) must be smaller than chunkSize ($chunkSize).',
      );
    }
  }

  Future<Document> storeDocument({
    required String fileName,
    required String filePath,
    required String content,
    int? fileSize,
    String? fileHash,
  }) async {
    if (_embeddingGenerator == null) {
      throw Exception('Embedding generator not set. Call setEmbeddingGenerator() first.');
    }

    final existingDoc = await getDocumentByFileName(fileName);

    if (existingDoc != null) {
      // Delete old chunks
      for (var chunk in existingDoc.chunks) {
        chunkBox.remove(chunk.id);
      }
      existingDoc.chunks.clear();
      
      // Create and store new chunks
      final chunks = _chunkContent(
        content,
        chunkSize: _chunkSize,
        chunkOverlap: _chunkOverlap,
      );
      for (final chunkContent in chunks) {
        final embedding = await _embeddingGenerator!(chunkContent);
        final chunk = DocumentChunk(content: chunkContent, embeddings: embedding);
        chunk.document.target = existingDoc;
        existingDoc.chunks.add(chunk);
      }
      
      existingDoc.filePath = filePath;
      existingDoc.fileSize = fileSize;
      existingDoc.fileHash = fileHash;
      existingDoc.updatedAt = DateTime.now();
      await updateDocument(existingDoc);
      return existingDoc;
    } else {
      final document = Document(
        fileName: fileName,
        filePath: filePath,
        fileSize: fileSize,
        fileHash: fileHash,
      );
      
      final chunks = _chunkContent(
        content,
        chunkSize: _chunkSize,
        chunkOverlap: _chunkOverlap,
      );
      for (final chunkContent in chunks) {
        final embedding = await _embeddingGenerator!(chunkContent);
        final chunk = DocumentChunk(content: chunkContent, embeddings: embedding);
        chunk.document.target = document;
        document.chunks.add(chunk);
      }
      
      document.id = documentBox.put(document);
      document.chunks.applyToDb();
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
    document.chunks.applyToDb();
  }

  Future<void> deleteDocument(int id) async {
    final doc = documentBox.get(id);
    if (doc != null) {
      // Remove associated chunks
      chunkBox.removeMany(doc.chunks.map((c) => c.id).toList());
      documentBox.remove(id);
    }
  }

  Future<List<ChunkSearchResult>> search({
    String? text,
    int limit = 10,
  }) async {
    if (text == null) {
      throw ArgumentError('text must be provided.');
    }

    if (_embeddingGenerator == null) {
      throw Exception('Embedding generator not set. Call setEmbeddingGenerator() first.');
    }

    final queryEmbedding = await _embeddingGenerator!(text);

    // Use ObjectBox's native vector search with HNSW index
    final query = chunkBox
        .query(DocumentChunk_.embeddings.nearestNeighborsF32(queryEmbedding, limit))
        .build();

    final results = query.findWithScores();
    query.close();
    return results.map((result) => ChunkSearchResult(
      chunk: result.object,
      distance: result.score,
    )).toList();
  }

  Future<DatabaseStats> getStats() async {
    final totalDocs = documentBox.count();
    final totalChunks = chunkBox.count();
    // This is an approximation of content length
    final allDocs = documentBox.getAll();
    final totalContentLength = allDocs.fold<int>(0, (sum, doc) => sum + doc.content.length);

    return DatabaseStats(
      totalDocuments: totalDocs,
      documentsWithEmbeddings: totalChunks, // Represents chunks with embeddings
      totalContentLength: totalContentLength,
    );
  }
}

class ChunkSearchResult {
  final DocumentChunk chunk;
  final double distance;

  ChunkSearchResult({required this.chunk, required this.distance});
}
