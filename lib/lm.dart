import 'dart:async';
import 'dart:io';

import 'package:cactus/context.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import './types.dart';

class CactusLM {
  int? _handle;
  String? _lastDownloadedFilename;

  Future<bool> downloadModel({
    String url = "https://huggingface.co/Cactus-Compute/Qwen3-600m-Instruct-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf",
    String? filename,
  }) async {
    final actualFilename = filename ?? url.split('/').last;
    final success = await _downloadModel(url, actualFilename);
    if (success) {
      _lastDownloadedFilename = actualFilename;
    }
    return success;
  }

  Future<bool> initializeModel({String? filename}) async {
    final modelFilename = filename ?? _lastDownloadedFilename ?? "Qwen3-0.6B-Q8_0.gguf";
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/$modelFilename';

    print('Initializing model at $modelPath');

    _handle = await CactusContext.initContext(modelPath);
    return _handle != null;
  }

  Future<CactusCompletionResult?> generateCompletion({
    required List<ChatMessage> messages,
    required CactusCompletionParams params,
  }) async {
    final currentHandle = _handle;
    if (currentHandle == null) return null;

    return await CactusContext.completion(currentHandle, messages, params);
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;

  Future<bool> _downloadModel(String url, String filename) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final filePath = '${appDocDir.path}/$filename';
    
    if (await File(filePath).exists()) {
      return true;
    }
    
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Failed to download model: ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      
      await for (final chunk in response) {
        sink.add(chunk);
      }
      
      await sink.close();
      return true;
    } catch (e) {
      debugPrint('Download failed: $e');
      return false;
    } finally {
      client.close();
    }
  }
}