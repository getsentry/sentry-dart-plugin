import 'dart:io';

import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:system_info2/system_info2.dart';

import 'cli/host_platform.dart';
import 'cli/setup.dart';
import 'utils/config-reader/config_reader.dart';
import 'utils/extensions.dart';
import 'utils/injector.dart';
import 'utils/log.dart';

class Configuration {
  late final FileSystem _fs = injector.get<FileSystem>();
  // cannot use ${Directory.current.path}/build since --split-debug-info allows
  // setting a custom path which is a sibling of build
  /// The Build folder, defaults to the current directory.
  late final String buildFilesFolder = _fs.currentDirectory.path;

  /// Whether to upload debug symbols, defaults to true
  late bool uploadDebugSymbols;

  /// Whether to upload source maps, defaults to false
  late bool uploadSourceMaps;

  /// Whether to upload source code, defaults to false
  late bool uploadSources;

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

  /// The Apps release name, defaults to 'name@version+buildNumber' from pubspec or set via env. var. SENTRY_RELEASE
  /// Example, name: 'my_app', version: 2.0.0+1, in this case the release is my_app@2.0.0+1
  /// This field has precedence over the [name] from pubspec
  /// If this field has a build number, it has precedence over the [version]'s build number from pubspec
  late String? release;

  /// The Apps dist/build number, taken from pubspec dist or SENTRY_DIST env. variable
  /// If provided, it will override the build number from [version]
  late String? dist;

  /// The Apps version, defaults to [version] from pubspec
  /// Example, version: 2.0.0+1, in this case the version is 2.0.0+1
  late String version;

  /// The Apps name, defaults to [name] from pubspec
  late String name;

  /// the Web Build folder, defaults to build/web
  late String webBuildFilesFolder;

  /// Associate commits with the release. Defaults to `auto` which will discover
  /// commits from the current project and compare them with the ones associated
  /// to the previous release. See docs for other options:
  /// https://docs.sentry.io/product/cli/releases/#sentry-cli-commit-integration
  /// Set to `false` to disable this feature completely.
  late String commits;

  /// Dealing With Missing Commits
  /// There are scenarios in which your repositories may be missing commits previously used in the release.
  /// https://docs.sentry.io/product/cli/releases/#dealing-with-missing-commits
  late bool ignoreMissing;

  /// Loads the configuration values
  Future<void> getConfigValues(List<String> arguments) async {
    const taskName = 'reading config values';
    Log.startingTask(taskName);
    await _findAndSetCliPath();

    final reader = ConfigReader();
    loadConfig(reader);

    Log.taskCompleted(taskName);
  }

  void loadConfig(ConfigReader reader) {
    final environments = Platform.environment;
    final pubspec = ConfigReader.getPubspec();

    release = reader.getString('release') ?? environments['SENTRY_RELEASE'];
    dist = reader.getString('dist') ?? environments['SENTRY_DIST'];
    version = pubspec['version'].toString();
    name = pubspec['name'].toString();

    uploadDebugSymbols = reader.getBool('upload_debug_symbols',
            deprecatedKey: 'upload_native_symbols') ??
        true;
    uploadSourceMaps = reader.getBool('upload_source_maps') ?? false;
    uploadSources = reader.getBool('upload_sources',
            deprecatedKey: 'include_native_sources') ??
        false;
    commits = (reader.getString('commits') ?? 'auto').toString();
    ignoreMissing = reader.getBool('ignore_missing') ?? false;

    // uploading JS and Map files need to have the correct folder structure
    // otherwise symbolication fails, the default path for the web build folder is build/web
    // but can be customized so making it flexible.
    final webBuildPath =
        reader.getString('web_build_path') ?? _fs.path.join('build', 'web');
    webBuildFilesFolder = _fs.path.join(buildFilesFolder, webBuildPath);

    project = reader.getString('project'); // or env. var. SENTRY_PROJECT
    org = reader.getString('org'); // or env. var. SENTRY_ORG
    waitForProcessing = reader.getBool('wait_for_processing') ?? false;
    authToken =
        reader.getString('auth_token'); // or env. var. SENTRY_AUTH_TOKEN
    url = reader.getString('url'); // or env. var. SENTRY_URL
    logLevel = reader.getString('log_level'); // or env. var. SENTRY_LOG_LEVEL
  }

  /// Validates the configuration values and log an error if required fields
  /// are missing
  bool validateConfigValues() {
    const taskName = 'validating config values';
    Log.startingTask(taskName);

    final environments = Platform.environment;

    var successful = true;
    if (project.isNull && environments['SENTRY_PROJECT'].isNull) {
      Log.error(
          'Project is empty, check \'project\' at pubspec.yaml or SENTRY_PROJECT env. var.');
      successful = false;
    }
    if (org.isNull && environments['SENTRY_ORG'].isNull) {
      Log.error(
          'Organization is empty, check \'org\' at pubspec.yaml or SENTRY_ORG env. var.');
      successful = false;
    }
    if (authToken.isNull && environments['SENTRY_AUTH_TOKEN'].isNull) {
      Log.error(
          'Auth Token is empty, check \'auth_token\' at pubspec.yaml or SENTRY_AUTH_TOKEN env. var.');
      successful = false;
    }

    try {
      injector.get<ProcessManager>().runSync([cliPath!, 'help']);
    } on Exception catch (exception) {
      Log.error(
          'sentry-cli is not available, please follow https://docs.sentry.io/product/cli/installation/ \n$exception');
      successful = false;
    }

    if (successful) {
      Log.taskCompleted(taskName);
    }
    return successful;
  }

  Future<void> _findAndSetCliPath() async {
    HostPlatform? platform;
    if (Platform.isMacOS) {
      platform = HostPlatform.darwinUniversal;
    } else if (Platform.isWindows) {
      platform = SysInfo.kernelBitness == 32
          ? HostPlatform.windows32bit
          : HostPlatform.windows64bit;
    } else if (Platform.isLinux) {
      switch (SysInfo.kernelArchitecture.name.toLowerCase()) {
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
      Log.error(
          'Host platform not supported - cannot download Sentry CLI for ${Platform.operatingSystem} ${SysInfo.kernelArchitecture}');
      return _setPreInstalledCli();
    }

    try {
      cliPath = await injector.get<CLISetup>().download(platform);
    } on Exception catch (e) {
      Log.error("Failed to download Sentry CLI: $e");
      return _setPreInstalledCli();
    }

    if (!Platform.isWindows) {
      final result =
          await injector.get<ProcessManager>().run(['chmod', '+x', cliPath!]);
      if (result.exitCode != 0) {
        Log.error(
            "Failed to make downloaded Sentry CLI executable: ${result.stdout}\n${result.stderr}");
        return _setPreInstalledCli();
      }
    }
  }

  void _setPreInstalledCli() {
    cliPath = Platform.isWindows ? 'sentry-cli.exe' : 'sentry-cli';
    Log.info(
        'Trying to fallback to preinstalled Sentry CLI, if available on PATH: $cliPath');
  }
}
