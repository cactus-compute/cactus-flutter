import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

String? _cactusToken;

void setCactusToken(String? token) {
  _cactusToken = token;
}

Future<List<double>> getVertexAIEmbedding(String text) async {
  if (_cactusToken == null) {
    throw Exception('CactusToken not set. Please call CactusLM.init with cactusToken parameter.');
  }

  const String projectId = 'cactus-v1-452518';
  const String location = 'us-central1';
  const String modelId = 'text-embedding-005';
  
  final String endpoint =
      'https://$location-aiplatform.googleapis.com/v1/projects/$projectId/locations/$location/publishers/google/models/$modelId:predict';

  final Map<String, String> headers = {
    'Authorization': 'Bearer $_cactusToken',
    'Content-Type': 'application/json',
  };

  final Map<String, dynamic> requestBody = {
    'instances': [
      {
        'content': text,
        'task_type': 'RETRIEVAL_DOCUMENT'
      }
    ]
  };

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody = json.decode(response.body);
      
      if (responseBody.containsKey('error')) {
        throw Exception('API Error: ${responseBody['error']['message']}');
      }
      
      final predictions = responseBody['predictions'] as List?;
      if (predictions == null || predictions.isEmpty) {
        throw Exception('No predictions in response');
      }
      
      final embeddings = predictions[0]['embeddings'];
      final values = embeddings['values'] as List;
      
      return values.map<double>((v) => v.toDouble()).toList();
    } else {
      throw Exception(
          'Failed to call Vertex AI. Status code: ${response.statusCode}\nBody: ${response.body}');
    }
  } catch (e) {
    throw Exception('An error occurred: $e');
  }
}

Future<String> getVertexAICompletion(
  String textPrompt, {
  Uint8List? imageData,
  String? imagePath,
  String? mimeType,
}) async {
  if (_cactusToken == null) {
    throw Exception('CactusToken not set. Please call CactusVLM.init with cactusToken parameter.');
  }

  const String projectId = 'cactus-v1-452518';
  const String location = 'global';
  const String modelId = 'gemini-2.5-flash-lite-preview-06-17';
  
  final String endpoint =
      'https://aiplatform.googleapis.com/v1/projects/$projectId/locations/$location/publishers/google/models/$modelId:generateContent';

  final Map<String, String> headers = {
    'Authorization': 'Bearer $_cactusToken',
    'Content-Type': 'application/json',
  };

  List<Map<String, dynamic>> parts = [
    {'text': textPrompt}
  ];

  if (imageData != null || imagePath != null) {
    Uint8List? finalImageData = imageData;
    String? finalMimeType = mimeType;

    if (imagePath != null && finalImageData == null) {
      final file = File(imagePath);
      if (await file.exists()) {
        finalImageData = await file.readAsBytes();
        
        if (finalMimeType == null) {
          final extension = imagePath.toLowerCase().split('.').last;
          switch (extension) {
            case 'jpg':
            case 'jpeg':
              finalMimeType = 'image/jpeg';
              break;
            case 'png':
              finalMimeType = 'image/png';
              break;
            case 'gif':
              finalMimeType = 'image/gif';
              break;
            case 'webp':
              finalMimeType = 'image/webp';
              break;
            default:
              finalMimeType = 'image/jpeg';
          }
        }
      } else {
        throw Exception('Image file not found: $imagePath');
      }
    }

    if (finalImageData != null) {
      final base64Image = base64Encode(finalImageData);
      parts.add({
        'inline_data': {
          'mime_type': finalMimeType ?? 'image/jpeg',
          'data': base64Image,
        }
      });
    }
  }

  final Map<String, dynamic> requestBody = {
    'contents': {
      'role': 'user',
      'parts': parts,
    }
  };

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final dynamic responseBody = json.decode(response.body);
      
      if (responseBody is Map && responseBody.containsKey('error')) {
        throw Exception('API Error: ${responseBody['error']['message']}');
      }
      
      dynamic candidates;
      if (responseBody is List) {
        candidates = responseBody;
      } else if (responseBody is Map && responseBody.containsKey('candidates')) {
        candidates = responseBody['candidates'];
      } else {
        throw Exception('Unexpected response format: ${response.body}');
      }
      
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No candidates in response');
      }
      
      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      if (parts.isEmpty) {
        throw Exception('No parts in response');
      }
      
      final String modelOutput = parts[0]['text'] ?? '';
      return modelOutput;
    } else {
      throw Exception(
          'Failed to call Vertex AI. Status code: ${response.statusCode}\nBody: ${response.body}');
    }
  } catch (e) {
    throw Exception('An error occurred: $e');
  }
}

Future<String> getTextCompletion(String textPrompt) async {
  return getVertexAICompletion(textPrompt);
}

Future<String> getVisionCompletion(String textPrompt, String imagePath) async {
  return getVertexAICompletion(textPrompt, imagePath: imagePath);
}

Future<String> getVisionCompletionFromData(String textPrompt, Uint8List imageData, {String? mimeType}) async {
  return getVertexAICompletion(textPrompt, imageData: imageData, mimeType: mimeType);
}
