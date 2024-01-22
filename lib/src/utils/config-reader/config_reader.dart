import 'dart:io';

import 'package:properties/properties.dart';
import 'package:yaml/yaml.dart';
import 'package:file/file.dart';

import '../injector.dart';
import '../log.dart';
import 'properties_config_reader.dart';
import 'yaml_config_reader.dart';

abstract class ConfigReader {
  String? getString(String key, {String? deprecatedKey});
  bool? getBool(String key, {String? deprecatedKey});
  bool contains(String key);

  /// By default this ConfigReader factory will try to load pubspec.yaml first.
  /// If the sentry config doesn't exist on pubspec.yaml it will use sentry.properties as fallback.
  factory ConfigReader() {
    // Attempt to retrieve the config from pubspec.yaml first
    final pubspec = getPubspec();
    final sentryConfig = pubspec['sentry'] as YamlMap?;
    if (sentryConfig != null) {
      Log.info('retrieving config from pubspec.yaml');
      return YamlConfigReader(sentryConfig);
    } else {
      Log.info('sentry config not found in pubspec.yaml');
    }

    // If sentry config is not found in pubspec.yaml, try loading from sentry.properties
    final propertiesFile = injector.get<FileSystem>().file("sentry.properties");
    if (propertiesFile.existsSync()) {
      Log.info('retrieving config from sentry.properties');
      // Loads properties class via string as there are issues loading the file
      // from path if run in the test suite
      final properties = Properties.fromString(propertiesFile.readAsStringSync());
      return PropertiesConfigReader(properties);
    }
    Log.error('sentry.properties not found: ${propertiesFile.absolute.path}');
    exit(1);
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
