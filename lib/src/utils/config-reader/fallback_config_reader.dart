import 'config_reader.dart';

class FallbackConfigReader implements ConfigReader {
  FallbackConfigReader(this._configReader, this._fallbackConfigReader);

  final ConfigReader? _configReader;
  final ConfigReader? _fallbackConfigReader;

  @override
  bool? getBool(String key, {String? deprecatedKey}) {
    return _configReader?.getBool(key, deprecatedKey: deprecatedKey) ??
        _fallbackConfigReader?.getBool(key, deprecatedKey: deprecatedKey);
  }

  @override
  String? getString(String key, {String? deprecatedKey}) {
    return _configReader?.getString(key, deprecatedKey: deprecatedKey) ??
        _fallbackConfigReader?.getString(key, deprecatedKey: deprecatedKey);
  }

  @override
  List<String>? getList(String key, {String? deprecatedKey}) {
    return _configReader?.getList(key, deprecatedKey: deprecatedKey) ??
        _fallbackConfigReader?.getList(key, deprecatedKey: deprecatedKey);
  }

  @override
  bool contains(String key) {
    return _configReader?.contains(key) ??
        _fallbackConfigReader?.contains(key) ??
        false;
  }
}
