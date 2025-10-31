import 'dart:convert';

import 'package:cactus/models/types.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelCache {
  static const String _modelKey = 'cactus_model';

  static Future<void> saveModel(CactusModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode({
        'created_at': model.createdAt.toIso8601String(),
        'slug': model.slug,
        'download_url': model.downloadUrl,
        'size_mb': model.sizeMb,
        'supports_tool_calling': model.supportsToolCalling,
        'supports_vision': model.supportsVision,
        'name': model.name,
        'is_downloaded': model.isDownloaded,
      });
      await prefs.setString("${_modelKey}_${model.slug}", jsonString);
    } catch (e) {
      debugPrint('Error saving model to cache: $e');
      rethrow;
    }
  }

  static Future<CactusModel?> loadModel(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString("${_modelKey}_$slug");
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      final Map<String, dynamic> json = jsonDecode(jsonString) as Map<String, dynamic>;
      return CactusModel(
        createdAt: DateTime.parse(json['created_at'] as String),
        slug: json['slug'] as String,
        downloadUrl: json['download_url'] as String,
        sizeMb: json['size_mb'] as int,
        supportsToolCalling: json['supports_tool_calling'] as bool,
        supportsVision: json['supports_vision'] as bool,
        name: json['name'] as String,
        isDownloaded: json['is_downloaded'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('Error loading model from cache: $e');
      return null;
    }
  }
}