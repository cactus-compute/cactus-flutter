import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cactus/src/services/context.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../src/services/telemetry.dart';

class CactusLM {
  int? _handle;
  String? _lastDownloadedModel;

  Future<bool> downloadModel({
    String model = "qwen3-0.6"
  }) async {
    final url = await Supabase.getModelDownloadUrl(model);
    if (url == null) {
      debugPrint('No download URL found for model: $model');
      return false;
    }
    final actualFilename = url.split('?').first.split('/').last;
    final success = await _downloadAndExtractModel(url, actualFilename, model);
    if (success) {
      _lastDownloadedModel = model;
    }
    return success;
  }

  Future<bool> initializeModel(CactusInitParams params) async {
    final modelFolder = params.model ?? _lastDownloadedModel ?? "qwen3-0.6";
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/$modelFolder';

    _handle = await CactusContext.initContext(modelPath, params.contextSize ?? 2048);
    _lastDownloadedModel = modelFolder;
    if(Telemetry.isInitialized) {
      params.model = modelFolder;
      Telemetry.instance?.logInit(_handle != null, params);
    }
    return _handle != null;
  }

  Future<CactusCompletionResult?> generateCompletion({
    required List<ChatMessage> messages,
    required CactusCompletionParams params,
  }) async {
    final currentHandle = _handle;
    if (currentHandle == null) {
      if(Telemetry.isInitialized) {
        Telemetry.instance?.logCompletion(null, CactusInitParams(), message: "Context not initialized", success: false);
      }
      return null;
    }

    try {
      final result = await CactusContext.completion(currentHandle, messages, params);
      
      // Track telemetry for successful completions (if telemetry is initialized)
      if (result.success && Telemetry.isInitialized) {
        final initParams = CactusInitParams(
          model: _lastDownloadedModel,
        );
        Telemetry.instance?.logCompletion(result, initParams, success: true);
      }
      
      return result;
    } catch (e) {
      // Track telemetry for errors (if telemetry is initialized)
      if (Telemetry.isInitialized) {
        final initParams = CactusInitParams(
          model: _lastDownloadedModel,
        );
        Telemetry.instance?.logCompletion(null, initParams, message: e.toString(), success: false);
      }
      rethrow;
    }
  }

  Future<CactusEmbeddingResult?> generateEmbedding({
    required String text,
    int bufferSize = 2048,
  }) async {
    final currentHandle = _handle;
    if (currentHandle == null) {
      debugPrint('Cannot generate embedding: Context not initialized');
      return null;
    }

    try {
      final result = await CactusContext.generateEmbedding(
        currentHandle,
        text,
        bufferSize: bufferSize,
      );
      
      debugPrint('Embedding generation ${result.success ? 'successful' : 'failed'}: '
                'dimension=${result.dimension}, '
                'embeddings_length=${result.embeddings.length}');
      
      return result;
    } catch (e) {
      debugPrint('Exception during embedding generation: $e');
      return CactusEmbeddingResult(
        success: false,
        embeddings: [],
        dimension: 0,
        errorMessage: e.toString(),
      );
    }
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;

  Future<bool> _downloadAndExtractModel(String url, String filename, String folder) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    
    // Create a folder for the extracted model weights
    final modelFolderPath = '${appDocDir.path}/$folder';
    final modelFolder = Directory(modelFolderPath);
    
    // Check if the model folder already exists and contains files
    if (await modelFolder.exists()) {
      final files = await modelFolder.list().toList();
      if (files.isNotEmpty) {
        debugPrint('Model folder already exists at $modelFolderPath with ${files.length} files');
        return true;
      }
    }
    
    // Download the ZIP file to temporary location
    final zipFilePath = '${appDocDir.path}/$filename';
    final client = HttpClient();
    
    try {
      debugPrint('Downloading ZIP file from $url');
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Failed to download ZIP file: ${response.statusCode}');
      }

      // Stream the response directly to a file to avoid memory issues
      final zipFile = File(zipFilePath);
      final sink = zipFile.openWrite();
      
      int totalBytes = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        totalBytes += chunk.length;
        
        // Log progress every 10MB
        if (totalBytes % (10 * 1024 * 1024) == 0) {
          debugPrint('Downloaded ${totalBytes ~/ (1024 * 1024)} MB...');
        }
      }
      
      await sink.close();
      debugPrint('Downloaded ${totalBytes} bytes to $zipFilePath');
      
      // Create the model folder if it doesn't exist
      await modelFolder.create(recursive: true);
      
      // Extract the ZIP file using streaming
      debugPrint('Extracting ZIP file with streaming...');
      
      final inputStream = InputFileStream(zipFilePath);
      
      try {
        final archive = ZipDecoder().decodeStream(inputStream);
        final symbolicLinks = [];
        
        for (final file in archive) {
          if (file.isSymbolicLink) {
            symbolicLinks.add(file);
            continue;
          }
          
          if (file.isFile) {
            final extractedFilePath = '$modelFolderPath/${file.name}';
            
            final extractedFileParent = File(extractedFilePath).parent;
            await extractedFileParent.create(recursive: true);            
            final outputStream = OutputFileStream(extractedFilePath);
            file.writeContent(outputStream);
            outputStream.closeSync();
          } else {
            final dirPath = '$modelFolderPath/${file.name}';
            await Directory(dirPath).create(recursive: true);
          }
        }
        
        for (final file in symbolicLinks) {
          final linkPath = '$modelFolderPath/${file.name}';
          final link = Link(linkPath);
          await link.create(file.symbolicLink!, recursive: true);
        }
      } finally {
        inputStream.close();
      }
      
      // Clean up the temporary ZIP file
      await zipFile.delete();
      debugPrint('ZIP extraction completed successfully to $modelFolderPath');
      return true;
    } catch (e) {
      debugPrint('Download and extraction failed: $e');
      // Clean up partial files on failure
      try {
        final zipFile = File(zipFilePath);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
        
        // Also try to clean up partial extraction if it failed midway
        if (await modelFolder.exists()) {
          // Only delete if it seems to be incomplete (has few files compared to expected)
          final files = await modelFolder.list().toList();
          if (files.length < 5) { // Assuming a model should have more than a few files
            await modelFolder.delete(recursive: true);
          }
        }
      } catch (cleanupError) {
        debugPrint('Error during cleanup: $cleanupError');
      }
      return false;
    } finally {
      client.close();
    }
  }
}