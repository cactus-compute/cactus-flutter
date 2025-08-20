class LogEntry {
  final int id;
  final String telemetryToken;
  final String? enterpriseKey;
  final String deviceMetadata;
  final String createdAt;
  final String updatedAt;

  LogEntry({
    required this.id,
    required this.telemetryToken,
    this.enterpriseKey,
    required this.deviceMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'],
      telemetryToken: json['telemetry_token'],
      enterpriseKey: json['enterprise_key'],
      deviceMetadata: json['device_metadata'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
