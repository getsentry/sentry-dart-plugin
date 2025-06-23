import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:system_info2/system_info2.dart';

import 'cli/host_platform.dart';
import 'cli/setup.dart';
import 'configuration_values.dart';
import 'utils/config-reader/config_reader.dart';
import 'utils/extensions.dart';
import 'utils/injector.dart';
import 'utils/log.dart';

class Configuration {
  late final FileSystem _fs = injector.get<FileSystem>();

  /// The Build folder, defaults `build`.
  late String buildFilesFolder;

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

  /// The Apps release name, defaults to 'name@version+buildNumber' from SENTRY_RELEASE env. variable, arguments or pubspec.
  /// Example, name: 'my_app', version: 2.0.0+1, in this case the release is my_app@2.0.0+1
  /// This field has precedence over the [name] from pubspec
  /// If this field has a build number, it has precedence over the [version]'s build number from pubspec
  late String? release;

  /// The Apps dist/build number, taken from SENTRY_DIST env. variable, arguments or pubspec.
  /// If provided, it will override the build number from [version]
  late String? dist;

  /// The Apps version, defaults to [version] from pubspec
  /// Example, version: 2.0.0+1, in this case the version is 2.0.0+1
  late String version;

  /// The Apps name, defaults to [name] from pubspec
  late String name;

  /// the Web Build folder, defaults to `web`.
  /// Relative to the [buildFilesFolder] so the default resolves to `build/web`.
  late String webBuildFilesFolder;

  /// The directory passed to `--split-debug-info`, defaults to '.'
  late String symbolsFolder;

  /// The URL prefix, defaults to null
  late String? urlPrefix;

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

  /// The directory where the sentry-cli binary is downloaded to. Defaults to
  /// `.dart_tool/pub/bin/sentry_dart_plugin`.
  late String binDir;

  /// An alternative path to sentry-cli. If provided, the SDK will not be
  /// downloaded. Please make sure to use the matching version.
  late String? binPath;

  /// Place to download sentry-cli. Defaults to
  /// `https://downloads.sentry-cdn.com/sentry-cli`.
  late String sentryCliCdnUrl;

  /// Override the sentry-cli version that should be downloaded
  late String? sentryCliVersion;

  /// Whether to use legacy web symbolication. Defaults to `false`.
  late bool legacyWebSymbolication;

  /// Loads the configuration values
  Future<void> getConfigValues(List<String> cliArguments) async {
    const taskName = 'reading config values';
    Log.startingTask(taskName);

    loadConfig(
      argsConfig: ConfigurationValues.fromArguments(cliArguments),
      fileConfig: ConfigurationValues.fromReader(ConfigReader()),
      platformEnvConfig: ConfigurationValues.fromPlatformEnvironment(
        Platform.environment,
      ),
    );

    await _findAndSetCliPath();

    Log.taskCompleted(taskName);
  }

  void loadConfig({
    required ConfigurationValues argsConfig,
    required ConfigurationValues fileConfig,
    required ConfigurationValues platformEnvConfig,
  }) {
    final pubspec = ConfigReader.getPubspec();

    final configValues = ConfigurationValues.merged(
      args: argsConfig,
      file: fileConfig,
      platformEnv: platformEnvConfig,
    );

    release = configValues.release;
    dist = configValues.dist;
    version = configValues.version ?? pubspec['version'].toString();
    name = configValues.name ?? pubspec['name'].toString();
    uploadDebugSymbols = configValues.uploadDebugSymbols ?? true;
    uploadSourceMaps = configValues.uploadSourceMaps ?? false;
    uploadSources = configValues.uploadSources ?? false;
    commits = configValues.commits ?? 'auto';
    ignoreMissing = configValues.ignoreMissing ?? false;

    buildFilesFolder = configValues.buildPath ?? 'build';
    // uploading JS and Map files need to have the correct folder structure
    // otherwise symbolication fails, the default path for the web build folder is web
    // but can be customized so making it flexible.
    final webBuildPath = configValues.webBuildPath ?? 'web';
    webBuildFilesFolder = _fs.path.join(buildFilesFolder, webBuildPath);
    symbolsFolder = configValues.symbolsPath ?? '.';

    project = configValues.project; // or env. var. SENTRY_PROJECT
    org = configValues.org; // or env. var. SENTRY_ORG
    waitForProcessing = configValues.waitForProcessing ?? false;
    authToken = configValues.authToken; // or env. var. SENTRY_AUTH_TOKEN
    url = configValues.url; // or env. var. SENTRY_URL
    urlPrefix = configValues.urlPrefix;
    logLevel = configValues.logLevel; // or env. var. SENTRY_LOG_LEVEL
    binDir = configValues.binDir ?? '.dart_tool/pub/bin/sentry_dart_plugin';
    binPath = configValues.binPath;
    sentryCliCdnUrl = configValues.sentryCliCdnUrl ??
        'https://downloads.sentry-cdn.com/sentry-cli';
    sentryCliVersion = configValues.sentryCliVersion;
    legacyWebSymbolication = configValues.legacyWebSymbolication ?? false;
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
    final platform = _getHostPlatform();
    final binPath = this.binPath;
    if (binPath != null && binPath.isNotEmpty) {
      if (platform != null) {
        await injector
            .get<CLISetup>()
            .check(platform, binPath, sentryCliCdnUrl, sentryCliVersion);
      } else {
        Log.warn('Host platform not supported. Cannot verify Sentry CLI.');
      }
      cliPath = binPath;
      Log.info("Using Sentry CLI at path '$cliPath'");
    } else {
      try {
        cliPath = await _downloadSentryCli(platform);
      } catch (e) {
        Log.error("Failed to download Sentry CLI: $e");

        cliPath = _getPreInstalledCli();
        Log.info('Trying to fallback to Sentry CLI at path: $cliPath');
      }
    }
  }

  String _getPreInstalledCli() {
    return Platform.isWindows ? 'sentry-cli.exe' : 'sentry-cli';
  }

  Future<String> _downloadSentryCli(HostPlatform? platform) async {
    if (platform == null) {
      throw Exception(
          'Host platform not supported: ${Platform.operatingSystem} ${SysInfo.kernelArchitecture}');
    }
    final cliPath = await injector
        .get<CLISetup>()
        .download(platform, binDir, sentryCliCdnUrl, sentryCliVersion);
    if (!Platform.isWindows) {
      final result =
          await injector.get<ProcessManager>().run(['chmod', '+x', cliPath]);
      if (result.exitCode != 0) {
        throw Exception(
            'Failed to make binary executable: ${result.stdout}\n${result.stderr}');
      }
    }
    return cliPath;
  }

  HostPlatform? _getHostPlatform() {
    if (Platform.isMacOS) {
      return HostPlatform.darwinUniversal;
    } else if (Platform.isWindows) {
      return SysInfo.kernelBitness == 32
          ? HostPlatform.windows32bit
          : HostPlatform.windows64bit;
    } else if (Platform.isLinux) {
      switch (SysInfo.kernelArchitecture.name.toLowerCase()) {
        case 'arm':
        case 'armv6':
        case 'armv7':
          return HostPlatform.linuxArmv7;
        case 'aarch64':
          return HostPlatform.linuxAarch64;
        case 'amd64':
        case 'x86_64':
          return HostPlatform.linux64bit;
      }
    }
    return null;
  }
}
