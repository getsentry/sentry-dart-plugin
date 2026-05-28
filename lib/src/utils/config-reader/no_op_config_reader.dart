import 'config_reader.dart';

class NoOpConfigReader implements ConfigReader {
  NoOpConfigReader();

  @override
  bool? getBool(String key, {String? deprecatedKey}) {
    return null;
  }

  @override
  String? getString(String key, {String? deprecatedKey}) {
    return null;
  }

  @override
  List<String>? getList(String key, {String? deprecatedKey}) {
    return null;
  }

  @override
  bool contains(String key) {
    return false;
  }
}
