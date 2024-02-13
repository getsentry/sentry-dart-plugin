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
  });

  factory ConfigurationValues.fromEnvironment() {
    stringFromEnv(String value) {
      final envString = String.fromEnvironment(value);
      return envString != "" ? envString : null;
    }

    boolFromEnv(String value) {
      final envString = String.fromEnvironment(value);
      return envString == "true"
          ? true
          : envString == "false"
              ? false
              : null;
    }

    return ConfigurationValues(
      version: stringFromEnv('version'),
      name: stringFromEnv('name'),
      uploadDebugSymbols: boolFromEnv('upload_debug_symbols') ??
          boolFromEnv('upload_native_symbols'),
      uploadSourceMaps: boolFromEnv('upload_sources'),
      uploadSources: boolFromEnv('upload_sources') ??
          boolFromEnv('include_native_sources'),
      project: stringFromEnv('project'),
      org: stringFromEnv('org'),
      authToken: stringFromEnv('auth_token'),
      url: stringFromEnv('url'),
      waitForProcessing: boolFromEnv('wait_for_processing'),
      logLevel: stringFromEnv('log_level'),
      release: stringFromEnv('release'),
      dist: stringFromEnv('dist'),
      webBuildPath: stringFromEnv('web_build_path'),
      commits: stringFromEnv('commits'),
      ignoreMissing: boolFromEnv('ignore_missing'),
    );
  }

  factory ConfigurationValues.fromReader(ConfigReader configReader) {
    return ConfigurationValues(
      version: configReader.getString('version'),
      name: configReader.getString('name'),
      uploadDebugSymbols: configReader.getBool('upload_debug_symbols',
          deprecatedKey: 'upload_native_symbols'),
      uploadSourceMaps: configReader.getBool('upload_source_maps'),
      uploadSources: configReader.getBool('upload_sources',
          deprecatedKey: 'include_native_sources'),
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
    );
  }

  factory ConfigurationValues.fromPlatformEnvironment(
    Map<String, String> environment,
  ) {
    return ConfigurationValues(
      release: environment['SENTRY_RELEASE'],
      dist: environment['SENTRY_DIST'],
    );
  }

  factory ConfigurationValues.merged(
    ConfigurationValues env,
    ConfigurationValues file,
    ConfigurationValues platformEnv,
  ) {
    return ConfigurationValues(
      version: env.version ?? file.version,
      name: env.name ?? file.name,
      uploadDebugSymbols: env.uploadDebugSymbols ?? file.uploadDebugSymbols,
      uploadSourceMaps: env.uploadSourceMaps ?? file.uploadSourceMaps,
      uploadSources: env.uploadSources ?? file.uploadSources,
      project: env.project ?? file.project,
      org: env.org ?? file.org,
      authToken: env.authToken ?? file.authToken,
      url: env.url ?? file.url,
      waitForProcessing: env.waitForProcessing ?? file.waitForProcessing,
      logLevel: env.logLevel ?? file.logLevel,
      release: env.release ?? file.release ?? platformEnv.release,
      dist: env.dist ?? file.dist ?? platformEnv.dist,
      webBuildPath: env.webBuildPath ?? file.webBuildPath,
      commits: env.commits ?? file.commits,
      ignoreMissing: env.ignoreMissing ?? file.ignoreMissing,
    );
  }
}
