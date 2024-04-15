// https://stackoverflow.com/a/73564526
import 'package:sentry_dart_plugin/src/utils/config-reader/config_reader.dart';

class ConfigurationValues {
  final String? version;
  final String? name;

  final bool? uploadDebugSymbols;
  final bool? uploadSourceMaps;
  final bool? uploadSources;
  final String? project;
  final String? org;
  final String? authToken;
  final String? url;
  final bool? waitForProcessing;
  final String? logLevel;
  final String? release;
  final String? dist;
  final String? webBuildPath;
  final String? commits;
  final bool? ignoreMissing;
  final String? binDir;
  final String? binPath;

  ConfigurationValues({
    this.version,
    this.name,
    this.uploadDebugSymbols,
    this.uploadSourceMaps,
    this.uploadSources,
    this.project,
    this.org,
    this.authToken,
    this.url,
    this.waitForProcessing,
    this.logLevel,
    this.release,
    this.dist,
    this.webBuildPath,
    this.commits,
    this.ignoreMissing,
    this.binDir,
    this.binPath,
  });

  factory ConfigurationValues.fromArguments(List<String> arguments) {
    Map<String, String> sentryArguments = {};
    for (final arg in arguments) {
      final components = arg.split("=");
      if (components.length < 3) {
        continue;
      }
      if (components[0] != "--sentry-define") {
        continue;
      }
      sentryArguments[components[1]] = components.sublist(2).join('=');
    }
    boolFromString(String? value) {
      return value == "true"
          ? true
          : value == "false"
              ? false
              : null;
    }

    return ConfigurationValues(
      version: sentryArguments['version'],
      name: sentryArguments['name'],
      uploadDebugSymbols: boolFromString(
        sentryArguments['upload_debug_symbols'] ??
            sentryArguments['upload_native_symbols'],
      ),
      uploadSourceMaps: boolFromString(sentryArguments['upload_source_maps']),
      uploadSources: boolFromString(
        sentryArguments['upload_sources'] ??
            sentryArguments['include_native_sources'],
      ),
      project: sentryArguments['project'],
      org: sentryArguments['org'],
      authToken: sentryArguments['auth_token'],
      url: sentryArguments['url'],
      waitForProcessing: boolFromString(sentryArguments['wait_for_processing']),
      logLevel: sentryArguments['log_level'],
      release: sentryArguments['release'],
      dist: sentryArguments['dist'],
      webBuildPath: sentryArguments['web_build_path'],
      commits: sentryArguments['commits'],
      ignoreMissing: boolFromString(sentryArguments['ignore_missing']),
      binDir: sentryArguments['bin_dir'],
      binPath: sentryArguments['bin_path'],
    );
  }

  factory ConfigurationValues.fromReader(ConfigReader configReader) {
    return ConfigurationValues(
      version: configReader.getString('version'),
      name: configReader.getString('name'),
      uploadDebugSymbols: configReader.getBool(
        'upload_debug_symbols',
        deprecatedKey: 'upload_native_symbols',
      ),
      uploadSourceMaps: configReader.getBool('upload_source_maps'),
      uploadSources: configReader.getBool(
        'upload_sources',
        deprecatedKey: 'include_native_sources',
      ),
      project: configReader.getString('project'),
      org: configReader.getString('org'),
      authToken: configReader.getString('auth_token'),
      url: configReader.getString('url'),
      waitForProcessing: configReader.getBool('wait_for_processing'),
      logLevel: configReader.getString('log_level'),
      release: configReader.getString('release'),
      dist: configReader.getString('dist'),
      webBuildPath: configReader.getString('web_build_path'),
      commits: configReader.getString('commits'),
      ignoreMissing: configReader.getBool('ignore_missing'),
      binDir: configReader.getString('bin_dir'),
      binPath: configReader.getString('bin_path'),
    );
  }

  factory ConfigurationValues.fromPlatformEnvironment(
    Map<String, String> environment,
  ) {
    String? envRelease = environment['SENTRY_RELEASE'];
    if (envRelease?.isEmpty ?? false) {
      envRelease = null;
    }
    String? envDist = environment['SENTRY_DIST'];
    if (envDist?.isEmpty ?? false) {
      envDist = null;
    }
    return ConfigurationValues(
      release: envRelease,
      dist: envDist,
    );
  }

  factory ConfigurationValues.merged({
    required ConfigurationValues platformEnv,
    required ConfigurationValues args,
    required ConfigurationValues file,
  }) {
    return ConfigurationValues(
      version: args.version ?? file.version,
      name: args.name ?? file.name,
      uploadDebugSymbols: args.uploadDebugSymbols ?? file.uploadDebugSymbols,
      uploadSourceMaps: args.uploadSourceMaps ?? file.uploadSourceMaps,
      uploadSources: args.uploadSources ?? file.uploadSources,
      project: args.project ?? file.project,
      org: args.org ?? file.org,
      authToken: args.authToken ?? file.authToken,
      url: args.url ?? file.url,
      waitForProcessing: args.waitForProcessing ?? file.waitForProcessing,
      logLevel: args.logLevel ?? file.logLevel,
      release: platformEnv.release ?? args.release ?? file.release,
      dist: platformEnv.dist ?? args.dist ?? file.dist,
      webBuildPath: args.webBuildPath ?? file.webBuildPath,
      commits: args.commits ?? file.commits,
      ignoreMissing: args.ignoreMissing ?? file.ignoreMissing,
      binDir: args.binDir ?? file.binDir,
      binPath: args.binPath ?? file.binPath,
    );
  }
}
