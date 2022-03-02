import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:system_info2/system_info2.dart';
import 'package:yaml/yaml.dart';

import 'utils/extensions.dart';
import 'utils/log.dart';

class Configuration {
  // cannot use ${Directory.current.path}/build since --split-debug-info allows
  // setting a custom path which is a sibling of build
  /// The Build folder, defaults to Directory.current
  String buildFilesFolder = Directory.current.path;

  /// Rather upload native debug symbols, defaults to true
  late bool uploadNativeSymbols;

  /// Rather upload source maps, defaults to false
  late bool uploadSourceMaps;

  /// Rather upload native source code, defaults to false
  late bool includeNativeSources;

  /// Wait for processing or not, defaults to false
  late bool waitForProcessing;

  /// The project name, or set via env. var. SENTRY_PROJECT
  late String? project;

  /// The Org slug, or set via env. var. SENTRY_ORG
  late String? org;

  /// The Auth token, or set via env. var. SENTRY_AUTH_TOKEN
  late String? authToken;

  /// The url, or set via env. var. SENTRY_URL
  late String? url;

  // The log level (trace, debug, info, warn, error), defaults to warn, or set env. var. SENTRY_LOG_LEVEL
  late String? logLevel;
  String? _assetsPath;

  // the Sentry CLI path, defaults to the assets folder
  late String? cliPath;
  final String _fileSeparator = Platform.pathSeparator;

  /// The Apps version, defaults to version from pubspec
  late String version;

  /// The Apps name, defaults to name from pubspec
  late String name;

  /// the Web Build folder, defaults to build/web
  late String webBuildFilesFolder;

  dynamic _getPubspec() {
    final pubspecString = File("pubspec.yaml").readAsStringSync();
    final pubspec = loadYaml(pubspecString);
    return pubspec;
  }

  /// Loads the configuration values
  Future<void> getConfigValues(List<String> arguments) async {
    const taskName = 'reading config values';
    Log.startingTask(taskName);

    await _getAssetsFolderPath();
    _findAndSetCliPath();
    final pubspec = _getPubspec();
    final config = pubspec['sentry'];

    version = config?['release']?.toString() ?? pubspec['version'].toString();
    name = pubspec['name'].toString();

    uploadNativeSymbols = config?['upload_native_symbols'] ?? true;
    uploadSourceMaps = config?['upload_source_maps'] ?? false;
    includeNativeSources = config?['include_native_sources'] ?? false;

    // uploading JS and Map files need to have the correct folder structure
    // otherwise symbolication fails, the default path for the web build folder is build/web
    // but can be customized so making it flexible.
    final webBuildPath = config?['web_build_path']?.toString() ?? 'build/web';
    webBuildFilesFolder = '$buildFilesFolder$_fileSeparator$webBuildPath';

    project = config?['project']?.toString(); // or env. var. SENTRY_PROJECT
    org = config?['org']?.toString(); // or env. var. SENTRY_ORG
    waitForProcessing = config?['wait_for_processing'] ?? false;
    authToken =
        config?['auth_token']?.toString(); // or env. var. SENTRY_AUTH_TOKEN
    url = config?['url']?.toString(); // or env. var. SENTRY_URL
    logLevel =
        config?['log_level']?.toString(); // or env. var. SENTRY_LOG_LEVEL

    Log.taskCompleted(taskName);
  }

  /// Validates the configuration values and log an error if required fields
  /// are missing
  void validateConfigValues() {
    const taskName = 'validating config values';
    Log.startingTask(taskName);

    final environments = Platform.environment;

    if (project.isNull && environments['SENTRY_PROJECT'].isNull) {
      Log.errorAndExit(
          'Project is empty, check \'project\' at pubspec.yaml or SENTRY_PROJECT env. var.');
    }
    if (org.isNull && environments['SENTRY_ORG'].isNull) {
      Log.errorAndExit(
          'Organization is empty, check \'org\' at pubspec.yaml or SENTRY_ORG env. var.');
    }
    if (authToken.isNull && environments['SENTRY_AUTH_TOKEN'].isNull) {
      Log.errorAndExit(
          'Auth Token is empty, check \'auth_token\' at pubspec.yaml or SENTRY_AUTH_TOKEN env. var.');
    }

    try {
      Process.runSync(cliPath!, ['help']);
    } catch (exception) {
      Log.errorAndExit(
          'sentry-cli is not available, please follow https://docs.sentry.io/product/cli/installation/ \n$exception');
    }

    Log.taskCompleted(taskName);
  }

  /// Get the assets folder path from the .packages file
  Future<void> _getAssetsFolderPath() async {
    final packagesConfig = await loadPackageConfig(File(
        '${Directory.current.path}$_fileSeparator.dart_tool${_fileSeparator}package_config.json'));

    final packages = packagesConfig.packages
        .where((package) => package.name == "sentry_dart_plugin");

    if (packages.isNotEmpty) {
      final path =
          packages.first.packageUriRoot.toString().replaceAll('file://', '') +
              'assets';

      _assetsPath = Uri.decodeFull(path);
    }

    if (_assetsPath.isNull) {
      Log.info('Can not find the assets folder.');
    }
  }

  void _findAndSetCliPath() {
    if (Platform.isMacOS) {
      _setCliPath("Darwin-x86_64");
    } else if (Platform.isWindows) {
      _setCliPath("Windows-i686.exe");
    } else if (Platform.isLinux) {
      final arch = SysInfo.kernelArchitecture;
      if (arch == "amd64") {
        _setCliPath("Linux-x86_64");
      } else {
        _setCliPath("Linux-$arch");
      }
    }

    if (cliPath != null) {
      final cliFile = File(cliPath!);

      if (!cliFile.existsSync()) {
        _setPreInstalledCli();
      }
    } else {
      _setPreInstalledCli();
    }
  }

  void _setPreInstalledCli() {
    Log.info(
        'sentry-cli is not available under the assets folder, using pre-installed sentry-cli');
    cliPath = 'sentry-cli';
  }

  void _setCliPath(String suffix) {
    cliPath = "$_assetsPath${_fileSeparator}sentry-cli-$suffix";
  }
}
