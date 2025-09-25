import 'document.dart';

class DocumentSearchResult {
  final Document document;
  final double similarity;

  DocumentSearchResult({
    required this.document,
    required this.similarity,
  });
}

class DatabaseStats {
  final int totalDocuments;
  final int documentsWithEmbeddings;
  final int totalContentLength;

  DatabaseStats({
    required this.totalDocuments,
    required this.documentsWithEmbeddings,
    required this.totalContentLength,
  });
}

class RagQueryResponse {
  final String response;
  final List<Document> sources;

  RagQueryResponse({
    required this.response,
    required this.sources,
  });
}
