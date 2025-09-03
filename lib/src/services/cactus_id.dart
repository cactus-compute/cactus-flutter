import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

class CactusId {
  static String? _cached;

  static Future<String> getProjectId({String seed = 'v1'}) async {
    if (_cached != null) return _cached!;
    final info = await PackageInfo.fromPlatform();
    final bundle = info.packageName;
    final ns = Namespace.url.value;
    final name = 'https://cactus-flutter/$bundle/$seed';
    _cached = const Uuid().v5(ns, name);
    return _cached!;
  }
}
