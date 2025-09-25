import 'package:objectbox/objectbox.dart';

@Entity()
class Document {
  @Id()
  int id = 0;

  @Unique()
  late String fileName;
  
  late String filePath;
  late String content;
  
  @Property(type: PropertyType.date)
  late DateTime createdAt;
  
  @Property(type: PropertyType.date)
  late DateTime updatedAt;
  
  late List<double> embeddings;
  int? fileSize;
  String? fileHash;

  Document({
    this.id = 0,
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.embeddings,
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
    content = '';
    embeddings = [];
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  void updateContent(String newContent, List<double> newEmbeddings) {
    content = newContent;
    embeddings = newEmbeddings;
    updatedAt = DateTime.now();
  }
}