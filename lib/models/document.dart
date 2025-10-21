import 'package:objectbox/objectbox.dart';

@Entity()
class Document {
  @Id()
  int id = 0;

  @Unique()
  late String fileName;

  late String filePath;

  @Property(type: PropertyType.date)
  late DateTime createdAt;

  @Property(type: PropertyType.date)
  late DateTime updatedAt;

  int? fileSize;
  String? fileHash;

  @Backlink('document')
  final chunks = ToMany<DocumentChunk>();

  Document({
    this.id = 0,
    required this.fileName,
    required this.filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.fileSize,
    this.fileHash,
  }) {
    this.createdAt = createdAt ?? DateTime.now();
    this.updatedAt = updatedAt ?? DateTime.now();
  }

  Document.empty() {
    fileName = '';
    filePath = '';
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  String get content => chunks.map((c) => c.content).join('\n\n');
}

@Entity()
class DocumentChunk {
  @Id()
  int id = 0;

  late String content;

  @Property(type: PropertyType.floatVector)
  @HnswIndex(dimensions: 1024)
  late List<double> embeddings;

  final document = ToOne<Document>();

  DocumentChunk({
    this.id = 0,
    required this.content,
    required this.embeddings,
  });
}