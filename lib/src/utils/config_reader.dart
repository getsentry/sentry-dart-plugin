import 'package:properties/properties.dart';
import 'package:yaml/yaml.dart';
import 'package:file/file.dart';

import 'injector.dart';
import 'log.dart';

abstract class ConfigReader {
  String? getString(String key, {String? deprecatedKey});
  bool? getBool(String key, {String? deprecatedKey});
  bool contains(String key);

  /// By default ConfigReader will try to load sentry.properties first.
  /// If sentry.properties doesn't exist it will use pubspec.yaml as fallback.
  factory ConfigReader() {
    final propertiesFile = injector.get<FileSystem>().file("sentry.properties");
    if (!propertiesFile.existsSync()) {
      Log.info(
          'sentry.properties not found: ${propertiesFile.absolute.path}, retrieving config from pubspec.yaml instead');
      final pubspec = _getPubspec();
      return PubspecConfigReader(pubspec['sentry'] as YamlMap?);
    }
    // Loads properties class via string as there are issues loading the file
    // from path if run in the test suite
    Log.info('retrieving config from sentry.properties');
    final properties = Properties.fromString(propertiesFile.readAsStringSync());
    return PropertiesConfigReader(properties);
  }
}

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
  bool contains(String key) {
    return _properties.contains(key);
  }
}

dynamic _getPubspec() {
  final file = injector.get<FileSystem>().file("pubspec.yaml");
  if (!file.existsSync()) {
    Log.error("Pubspec not found: ${file.absolute.path}");
    return {};
  }
  final pubspecString = file.readAsStringSync();
  final pubspec = loadYaml(pubspecString);
  return pubspec;
}

class PubspecConfigReader implements ConfigReader {
  final YamlMap? _pubspec;

  PubspecConfigReader(YamlMap? pubspec) : _pubspec = pubspec;

  @override
  bool? getBool(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => _pubspec?[key] as bool?);
  }

  @override
  String? getString(String key, {String? deprecatedKey}) {
    return get(key, deprecatedKey, (key) => (_pubspec?[key]).toString());
  }

  @override
  bool contains(String key) {
    return _pubspec?.containsKey(key) ?? false;
  }
}

extension _Config on ConfigReader {
  T? get<T>(
      String name, String? deprecatedName, T? Function(String key) resolve) {
    if (deprecatedName != null && contains(deprecatedName)) {
      Log.warn(
          'Your pubspec.yaml contains `$deprecatedName` which is deprecated. Consider switching to `$name`.');
    }
    if (contains(name)) {
      return resolve(name);
    } else if (deprecatedName != null && contains(deprecatedName)) {
      return resolve(deprecatedName);
    } else {
      return null;
    }
  }
}
