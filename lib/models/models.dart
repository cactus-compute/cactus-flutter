class Model {
  final DateTime createdAt;
  final String slug;
  final String downloadUrl;
  final int sizeMb;
  final bool supportsToolCalling;
  final bool supportsVision;
  final String name;

  Model({
    required this.createdAt,
    required this.slug,
    required this.downloadUrl,
    required this.sizeMb,
    required this.supportsToolCalling,
    required this.supportsVision,
    required this.name,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      createdAt: DateTime.parse(json['created_at'] as String),
      slug: json['slug'] as String,
      downloadUrl: json['download_url'] as String,
      sizeMb: json['size_mb'] as int,
      supportsToolCalling: json['supports_tool_calling'] as bool,
      supportsVision: json['supports_vision'] as bool,
      name: json['name'] as String,
    );
  }
}