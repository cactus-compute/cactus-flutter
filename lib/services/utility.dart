import 'package:cactus/models/types.dart';
import 'package:cactus/src/services/supabase.dart';

class CactusUtils{
  static Future<List<CactusModel>> listModels() async {
    return Supabase.fetchModels();
  }
}