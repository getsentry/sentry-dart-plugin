import 'package:yaml/yaml.dart';

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
  List<String>? getList(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) {
      final value = _yamlMap?[key];
      if (value is YamlList) {
        return value.map((e) => e.toString()).toList();
      } else if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return null;
    });
  }

  @override
  bool contains(String key) {
    return _yamlMap?.containsKey(key) ?? false;
  }
}
