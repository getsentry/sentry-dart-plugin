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
        return value.split(',').map((e) => e.trim()).toList();
      }
      return null;
    });
  }

  @override
  bool contains(String key) {
    return _properties.contains(key);
  }
}
