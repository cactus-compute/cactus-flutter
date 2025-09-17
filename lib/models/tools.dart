import 'dart:convert';

class ToolParameter {
  final String type;
  final String description;
  final bool required;

  ToolParameter({
    required this.type,
    required this.description,
    this.required = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'required': required,
    };
  }

  factory ToolParameter.fromJson(Map<String, dynamic> json) {
    return ToolParameter(
      type: json['type'] as String,
      description: json['description'] as String,
      required: json['required'] as bool? ?? false,
    );
  }
}

class ToolParametersSchema {
  final String type;
  final Map<String, ToolParameter> properties;
  final List<String> required;

  ToolParametersSchema({
    this.type = 'object',
    required this.properties,
  }) : required = properties.entries
            .where((entry) => entry.value.required)
            .map((entry) => entry.key)
            .toList();

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'properties': properties.map((k, v) => MapEntry(k, v.toJson())),
      'required': required,
    };
  }

  factory ToolParametersSchema.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};

    return ToolParametersSchema(
      type: json['type'] as String? ?? 'object',
      properties: properties.map(
        (k, v) => MapEntry(k, ToolParameter.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

class CactusTool {
  final String name;
  final String description;
  final ToolParametersSchema parameters;

  CactusTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters.toJson(),
      }
    };
  }

  factory CactusTool.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>;
    return CactusTool(
      name: function['name'] as String,
      description: function['description'] as String,
      parameters: ToolParametersSchema.fromJson(
          function['parameters'] as Map<String, dynamic>),
    );
  }
}

class ToolCall {
  final String name;
  final Map<String, String> arguments;

  ToolCall({
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arguments': arguments,
    };
  }

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final args = json['arguments'] as Map<String, dynamic>? ?? {};
    return ToolCall(
      name: json['name'] as String,
      arguments: args.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

extension ToolListExtension on List<CactusTool> {
  String toToolsJson() {
    return jsonEncode(map((tool) => tool.toJson()).toList());
  }
}

CactusTool createTool(
  String name,
  String description,
  Map<String, ToolParameter> parameters,
) {
  return CactusTool(
    name: name,
    description: description,
    parameters: ToolParametersSchema(
      properties: parameters,
    ),
  );
}