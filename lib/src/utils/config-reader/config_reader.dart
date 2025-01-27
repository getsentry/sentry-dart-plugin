import 'package:properties/properties.dart';
import 'package:sentry_dart_plugin/src/utils/config-reader/fallback_config_reader.dart';
import 'package:yaml/yaml.dart';
import 'package:file/file.dart';

import '../injector.dart';
import '../log.dart';
import 'no_op_config_reader.dart';
import 'properties_config_reader.dart';
import 'yaml_config_reader.dart';

abstract class ConfigReader {
  String? getString(String key, {String? deprecatedKey});
  bool? getBool(String key, {String? deprecatedKey});
  bool contains(String key);

  /// This factory will try to load both pubspec.yaml and sentry.properties.
  /// If a sentry config key doesn't exist on pubspec.yaml it will use sentry.properties as fallback.
  factory ConfigReader() {
    YamlConfigReader? pubspecReader;

    final pubspec = getPubspec();
    final sentryConfig = pubspec['sentry'] as YamlMap?;
    if (sentryConfig != null) {
      Log.info('Found config from pubspec.yaml');
      pubspecReader = YamlConfigReader(sentryConfig);
    } else {
      Log.info('sentry config not found in pubspec.yaml');
    }

    PropertiesConfigReader? propertiesReader;

    final propertiesFile = injector.get<FileSystem>().file("sentry.properties");
    if (propertiesFile.existsSync()) {
      Log.info('Found config from sentry.properties');
      // Loads properties class via string as there are issues loading the file
      // from path if run in the test suite
      final properties =
          Properties.fromString(propertiesFile.readAsStringSync());
      propertiesReader = PropertiesConfigReader(properties);
    }

    if (pubspecReader == null && propertiesReader == null) {
      Log.warn(
          'No file config found. Reading values from arguments or environment.');
      return NoOpConfigReader();
    } else {
      return FallbackConfigReader(pubspecReader, propertiesReader);
    }
  }

  static dynamic getPubspec() {
    final file = injector.get<FileSystem>().file("pubspec.yaml");
    if (!file.existsSync()) {
      Log.error("Pubspec not found: ${file.absolute.path}");
      return {};
    }
    final pubspecString = file.readAsStringSync();
    final pubspec = loadYaml(pubspecString);
    return pubspec;
  }
}

extension Config on ConfigReader {
  T? get<T>(
      String name, String? deprecatedName, T? Function(String key) resolve) {
    if (deprecatedName != null && contains(deprecatedName)) {
      Log.warn(
          'Your config contains `$deprecatedName` which is deprecated. Consider switching to `$name`.');
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
