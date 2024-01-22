import 'package:yaml/yaml.dart';

import '../log.dart';
import 'config_reader.dart';

class YamlConfigReader implements ConfigReader {
  final YamlMap? _yamlMap;

  YamlConfigReader(YamlMap? yamlMap) : _yamlMap = yamlMap;

  @override
  bool? getBool(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => _yamlMap?[key] as bool?);
  }

  @override
  String? getString(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => (_yamlMap?[key]).toString());
  }

  @override
  bool contains(String key) {
    return _yamlMap?.containsKey(key) ?? false;
  }
}
