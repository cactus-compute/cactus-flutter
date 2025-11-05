import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:cactus/models/types.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  /// Check if a model/folder exists and contains files
  static Future<bool> modelExists(String folderName, [String? basePath]) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelFolderPath = basePath ?? '${appDocDir.path}/models/$folderName';
    final modelFolder = Directory(modelFolderPath);
    if (await modelFolder.exists()) {
      final files = await modelFolder.list().toList();
      return files.isNotEmpty;
    }
    return false;
  }

  /// Download and extract multiple models/files
  static Future<bool> downloadAndExtractModels(
    List<DownloadTask> tasks,
    CactusProgressCallback? downloadProcessCallback,
    [String? basePath]
  ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(basePath ?? '${appDocDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final progress = i / tasks.length;
      
      downloadProcessCallback?.call(
        progress,
        'Downloading ${task.folder}...',
        false,
      );

      final success = await _downloadAndExtractModel(
        task.url,
        task.filename,
        task.folder,
        downloadProcessCallback,
        basePath,
      );

      if (!success) {
        return false;
      }
    }

    downloadProcessCallback?.call(1.0, 'All downloads completed successfully', false);
    return true;
  }

  /// Download and extract a single model/file
  static Future<bool> _downloadAndExtractModel(
    String url,
    String filename,
    String folder,
    CactusProgressCallback? downloadProcessCallback,
    [String? basePath]
  ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelFolderPath = basePath != null 
        ? '$basePath/$folder' 
        : '${appDocDir.path}/models/$folder';
    final modelFolder = Directory(modelFolderPath);
    
    if (await modelFolder.exists()) {
      final files = await modelFolder.list().toList();
      if (files.isNotEmpty) {
        debugPrint('Model folder already exists at $modelFolderPath with ${files.length} files');
        return true;
      }
    }
    
    final modelsDir = Directory(basePath ?? '${appDocDir.path}/models');
    await modelsDir.create(recursive: true);
    final zipFilePath = '${modelsDir.path}/$filename';
    final client = HttpClient();
    
    try {
      debugPrint('Downloading file from $url');
      downloadProcessCallback?.call(null, 'Starting download...', false);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        downloadProcessCallback?.call(null, 'Failed to download file: ${response.statusCode}', true);
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      downloadProcessCallback?.call(null, 'Download started...', false);
      final zipFile = File(zipFilePath);
      final sink = zipFile.openWrite();
      
      int totalBytes = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        totalBytes += chunk.length;
        if (contentLength > 0) {
          final progress = totalBytes / contentLength;
          downloadProcessCallback?.call(progress, 'Downloaded ${totalBytes ~/ (1024 * 1024)} MB...', false);
        } else if (totalBytes % (10 * 1024 * 1024) == 0) {
          downloadProcessCallback?.call(null, 'Downloaded ${totalBytes ~/ (1024 * 1024)} MB...', false);
        }
      }
      await sink.close();
      downloadProcessCallback?.call(1.0, 'Download completed, extracting...', false);

      // Check if file is a zip archive by extension
      if (filename.toLowerCase().endsWith('.zip')) {
        await _extractZipFile(zipFilePath, modelFolderPath, downloadProcessCallback);
      } else {
        // For non-zip files, just move to the destination folder
        await modelFolder.create(recursive: true);
        final destinationPath = '$modelFolderPath/$filename';
        await zipFile.rename(destinationPath);
      }
      
      // Clean up zip file if it was extracted
      if (filename.toLowerCase().endsWith('.zip')) {
        await zipFile.delete();
      }
      
      downloadProcessCallback?.call(1.0, 'Download completed successfully', false);
      debugPrint('Download completed successfully to $modelFolderPath');
      return true;
    } catch (e) {
      downloadProcessCallback?.call(null, 'Download failed: $e', true);
      debugPrint('Download failed: $e');
      try {
        final zipFile = File(zipFilePath);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
        if (await modelFolder.exists()) {
          final files = await modelFolder.list().toList();
          if (files.length < 5) {
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

  /// Extract a zip file to the specified directory
  static Future<void> _extractZipFile(
    String zipFilePath, 
    String extractToPath, 
    CactusProgressCallback? downloadProcessCallback
  ) async {
    final modelFolder = Directory(extractToPath);
    await modelFolder.create(recursive: true);
    downloadProcessCallback?.call(null, 'Extracting files...', false);
    
    final inputStream = InputFileStream(zipFilePath);
    
    try {
      final archive = ZipDecoder().decodeStream(inputStream);
      final symbolicLinks = <ArchiveFile>[];
      
      // Find the root folder name in the archive
      String? rootFolderName;
      for (final file in archive) {
        if (file.isFile || file.isDirectory) {
          final pathParts = file.name.split('/');
          if (pathParts.isNotEmpty && rootFolderName == null) {
            rootFolderName = pathParts.first;
          }
          // Break after finding the first file/directory to get the root folder
          if (rootFolderName != null) break;
        }
      }
      
      debugPrint('Root folder in archive: $rootFolderName');
      
      for (final file in archive) {
        if (file.isSymbolicLink) {
          symbolicLinks.add(file);
          continue;
        }
        
        // Skip the root folder and extract contents directly to extractToPath
        String relativePath = file.name;
        if (rootFolderName != null && relativePath.startsWith('$rootFolderName/')) {
          relativePath = relativePath.substring(rootFolderName.length + 1);
        }
        
        // Skip empty paths (root folder itself)
        if (relativePath.isEmpty) continue;
        
        if (file.isFile) {
          final extractedFilePath = '$extractToPath/$relativePath';
          
          final extractedFileParent = File(extractedFilePath).parent;
          await extractedFileParent.create(recursive: true);            
          final outputStream = OutputFileStream(extractedFilePath);
          file.writeContent(outputStream);
          outputStream.closeSync();
        } else {
          final dirPath = '$extractToPath/$relativePath';
          await Directory(dirPath).create(recursive: true);
        }
      }
      
      // Handle symbolic links
      for (final file in symbolicLinks) {
        String relativePath = file.name;
        if (rootFolderName != null && relativePath.startsWith('$rootFolderName/')) {
          relativePath = relativePath.substring(rootFolderName.length + 1);
        }
        
        if (relativePath.isNotEmpty) {
          final linkPath = '$extractToPath/$relativePath';
          final link = Link(linkPath);
          await link.create(file.symbolicLink!, recursive: true);
        }
      }
    } finally {
      inputStream.close();
    }
  }
}

class DownloadTask {
  final String url;
  final String filename;
  final String folder;

  DownloadTask({
    required this.url,
    required this.filename,
    required this.folder,
  });
}