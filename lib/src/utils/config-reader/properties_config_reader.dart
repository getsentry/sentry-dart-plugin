import 'package:properties/properties.dart';

import 'config_reader.dart';

class PropertiesConfigReader implements ConfigReader {
  final Properties _properties;

  PropertiesConfigReader(Properties properties) : _properties = properties;

  @override
  bool? getBool(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => _properties.getBool((key)));
  }

  @override
  String? getString(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => _properties.get((key)));
  }

  @override
  List<String>? getList(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) {
      final value = _properties.get(key);
      if (value != null && value.isNotEmpty) {
        final stripped = value.startsWith('[') && value.endsWith(']')
            ? value.substring(1, value.length - 1)
            : value;
        return stripped
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return null;
    });
  }

  @override
  bool contains(String key) {
    return _properties.contains(key);
  }
}
