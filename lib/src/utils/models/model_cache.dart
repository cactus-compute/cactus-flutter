import 'dart:convert';

import 'package:cactus/models/types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelCache {
  static const String _modelsKey = 'cactus_models';

  static Future<void> saveModels(List<CactusModel> models) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(models.map((model) => {
        'created_at': model.createdAt.toIso8601String(),
        'slug': model.slug,
        'download_url': model.downloadUrl,
        'size_mb': model.sizeMb,
        'supports_tool_calling': model.supportsToolCalling,
        'supports_vision': model.supportsVision,
        'name': model.name,
        'is_downloaded': model.isDownloaded,
      }).toList());
      await prefs.setString(_modelsKey, jsonString);
    } catch (e) {
      print('Error saving models to cache: $e');
      rethrow;
    }
  }

  static Future<List<CactusModel>> loadModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_modelsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      final models = jsonList.map((json) => CactusModel(
        createdAt: DateTime.parse(json['created_at'] as String),
        slug: json['slug'] as String,
        downloadUrl: json['download_url'] as String,
        sizeMb: json['size_mb'] as int,
        supportsToolCalling: json['supports_tool_calling'] as bool,
        supportsVision: json['supports_vision'] as bool,
        name: json['name'] as String,
        isDownloaded: json['is_downloaded'] as bool? ?? false,
      )).toList();
      return models;
    } catch (e) {
      print('Error loading models from cache: $e');
      return [];
    }
  }
}