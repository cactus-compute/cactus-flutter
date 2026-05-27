import 'dart:convert';
import 'dart:io';

import 'package:cactus/cactus.dart';
import 'package:cactus/src/services/api/supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingHttpOverrides extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts += 1;
    throw const SocketException(
      'Test override: network access is forbidden when telemetry is disabled',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ThrowingHttpOverrides overrides;
  late bool originalTelemetryEnabled;

  setUp(() {
    originalTelemetryEnabled = CactusConfig.isTelemetryEnabled;
    overrides = _ThrowingHttpOverrides();
    HttpOverrides.global = overrides;
  });

  tearDown(() async {
    HttpOverrides.global = null;
    CactusConfig.isTelemetryEnabled = originalTelemetryEnabled;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Supabase honors isTelemetryEnabled = false', () {
    test('getModel returns cached model without constructing HttpClient', () async {
      CactusConfig.isTelemetryEnabled = false;
      final cached = jsonEncode(<String, dynamic>{
        'created_at': '2025-01-01T00:00:00.000Z',
        'slug': 'qwen3-0.6',
        'download_url': 'https://example.com/qwen3-0.6.gguf',
        'size_mb': 600,
        'supports_tool_calling': true,
        'supports_vision': false,
        'name': 'Qwen 3 0.6B',
        'is_downloaded': false,
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cactus_model_qwen3-0.6': cached,
      });

      final model = await Supabase.getModel('qwen3-0.6');

      expect(model, isNotNull);
      expect(model!.slug, 'qwen3-0.6');
      expect(model.name, 'Qwen 3 0.6B');
      expect(
        overrides.attempts,
        0,
        reason: 'getModel must not construct HttpClient when telemetry is off',
      );
    });

    test('getModel returns null on cache miss without constructing HttpClient', () async {
      CactusConfig.isTelemetryEnabled = false;
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final model = await Supabase.getModel('unknown-slug');

      expect(model, isNull);
      expect(overrides.attempts, 0);
    });

    test('fetchModels returns const empty list without constructing HttpClient', () async {
      CactusConfig.isTelemetryEnabled = false;

      final models = await Supabase.fetchModels();

      expect(models, isEmpty);
      expect(
        overrides.attempts,
        0,
        reason: 'fetchModels must not construct HttpClient when telemetry is off',
      );
    });

    test('fetchVoiceModels returns const empty list without constructing HttpClient', () async {
      CactusConfig.isTelemetryEnabled = false;

      final voiceModels = await Supabase.fetchVoiceModels();

      expect(voiceModels, isEmpty);
      expect(
        overrides.attempts,
        0,
        reason: 'fetchVoiceModels must not construct HttpClient when telemetry is off',
      );
    });

    test('fetchVoiceModels guard fires before provider-specific branching', () async {
      CactusConfig.isTelemetryEnabled = false;

      final voiceModels = await Supabase.fetchVoiceModels(provider: 'whisper');

      expect(voiceModels, isEmpty);
      expect(overrides.attempts, 0);
    });
  });
}
