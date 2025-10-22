import 'dart:math';
import 'package:cactus/models/tools.dart';
import 'package:cactus/services/lm.dart';

enum ToolFilterStrategy {
  /// Simple keyword matching with fuzzy matching and scoring (default, fast)
  simple,
  /// Semantic search using embeddings for understanding intent (slower but more accurate)
  semantic,
}

class ToolFilterConfig {
  final ToolFilterStrategy strategy;
  final int? maxTools;
  final double similarityThreshold;

  const ToolFilterConfig({
    this.strategy = ToolFilterStrategy.simple,
    this.maxTools,
    this.similarityThreshold = 0.3,
  });
  
  factory ToolFilterConfig.simple({int maxTools = 3}) {
    return ToolFilterConfig(
      strategy: ToolFilterStrategy.simple,
      maxTools: maxTools,
      similarityThreshold: 0.3,
    );
  }
}

class ToolFilterService {
  final ToolFilterConfig config;
  final CactusLM _lm;

  ToolFilterService({ToolFilterConfig? config, required CactusLM lm})
      : config = config ?? const ToolFilterConfig(),
        _lm = lm;

  Future<List<CactusTool>> filterTools(String query, List<CactusTool> tools) async {
    if (tools.isEmpty) return tools;
    
    switch (config.strategy) {
      case ToolFilterStrategy.simple:
        return _filterByEnhancedKeyword(query, tools);
      case ToolFilterStrategy.semantic:
        return await _filterBySemantic(query, tools);
    }
  }

  List<CactusTool> _filterByEnhancedKeyword(String query, List<CactusTool> tools) {
    final queryLower = query.toLowerCase();
    final queryWords = _extractKeywords(queryLower);
    
    if (queryWords.isEmpty) {
      return _applyMaxToolsLimit(tools);
    }
    
    final scoredTools = tools.map((tool) {
      final score = _calculateToolScore(tool, queryWords);
      return _ScoredTool(tool, score);
    }).toList();
    
    scoredTools.sort((a, b) => b.score.compareTo(a.score));
    
    final filteredTools = scoredTools
        .where((st) => st.score >= config.similarityThreshold)
        .map((st) => st.tool)
        .toList();
    
    if (filteredTools.isEmpty) {
      return _applyMaxToolsLimit(tools);
    }
    
    return _applyMaxToolsLimit(filteredTools);
  }

  Future<List<CactusTool>> _filterBySemantic(String query, List<CactusTool> tools) async {    
    try {
      final queryEmbedding = await _lm.generateEmbedding(text: query);
      if (!queryEmbedding.success) {
        return _filterByEnhancedKeyword(query, tools);
      }

      final scoredTools = <_ScoredTool>[];
      for (final tool in tools) {
        final toolText = '${tool.name}: ${tool.description}\nParameters: ${tool.parameters.properties.keys.join(", ")}';
        final toolEmbedding = await _lm.generateEmbedding(text: toolText);
        
        if (toolEmbedding.success) {
          final similarity = _cosineSimilarity(queryEmbedding.embeddings, toolEmbedding.embeddings);
          scoredTools.add(_ScoredTool(tool, similarity));
        }
      }

      scoredTools.sort((a, b) => b.score.compareTo(a.score));
      final filteredTools = scoredTools
          .where((st) => st.score >= config.similarityThreshold)
          .map((st) => st.tool)
          .toList();

      if (filteredTools.isEmpty) {
        return _filterByEnhancedKeyword(query, tools);
      }

      return _applyMaxToolsLimit(filteredTools);
    } catch (e) {
      return _filterByEnhancedKeyword(query, tools);
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double _calculateToolScore(CactusTool tool, List<String> queryWords) {
    if (queryWords.isEmpty) return 0.0;
    
    final toolText = '${tool.name} ${tool.description}'.toLowerCase();
    final matchedWords = queryWords.where((word) => toolText.contains(word)).length;
    
    return matchedWords / queryWords.length;
  }

  List<String> _extractKeywords(String query) {
    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 2)
        .toList();
  }

  List<CactusTool> _applyMaxToolsLimit(List<CactusTool> tools) {
    if (config.maxTools == null || tools.length <= config.maxTools!) {
      return tools;
    }
    return tools.sublist(0, config.maxTools!);
  }
}

class _ScoredTool {
  final CactusTool tool;
  final double score;
  
  _ScoredTool(this.tool, this.score);
}
