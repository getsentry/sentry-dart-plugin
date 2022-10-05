import 'dart:io';

import 'package:file/local.dart';
import 'package:sentry_dart_plugin/src/cli/_sources.dart';
import 'package:system_info2/system_info2.dart';
import 'package:yaml/yaml.dart';

import 'cli/host_platform.dart';
import 'cli/setup.dart';
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
    final environments = Platform.environment;
    const taskName = 'reading config values';
    Log.startingTask(taskName);

    await _findAndSetCliPath();
    final pubspec = _getPubspec();
    final config = pubspec['sentry'];

    version = config?['release']?.toString() ??
        environments['SENTRY_RELEASE'] ??
        pubspec['version'].toString(); // or env. var. SENTRY_RELEASE
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

  Future<void> _findAndSetCliPath() async {
    final fs = LocalFileSystem();
    final cliSetup = CLISetup(fs, currentCLISources);
    HostPlatform? platform;
    if (Platform.isMacOS) {
      platform = HostPlatform.darwinUniversal;
    } else if (Platform.isWindows) {
      platform = SysInfo.kernelBitness == 32
          ? HostPlatform.windows32bit
          : HostPlatform.windows64bit;
    } else if (Platform.isLinux) {
      switch (SysInfo.kernelArchitecture.toLowerCase()) {
        case 'arm':
        case 'armv6':
        case 'armv7':
          platform = HostPlatform.linuxArmv7;
          break;
        case 'aarch64':
          platform = HostPlatform.linuxAarch64;
          break;
        case 'amd64':
        case 'x86_64':
          platform = HostPlatform.linux64bit;
          break;
      }
    }

    if (platform == null) {
      Log.errorAndExit(
          'Host platform not supported - cannot download Sentry CLI for ${Platform.operatingSystem} ${SysInfo.kernelArchitecture}');
    }

    try {
      cliPath = await cliSetup.download(platform);
    } catch (e) {
      Log.errorAndExit("Failed to download Sentry CLI: $e");
    }

    var result = await Process.run('chmod', ['+x', cliPath!]);
    if (result.exitCode != 0) {
      Log.errorAndExit(
          "Failed to make Sentry CLI executable: ${result.stdout}\n${result.stderr}");
    }
  }
}
