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
  final String? urlPrefix;
  final bool? waitForProcessing;
  final String? logLevel;
  final String? release;
  final String? dist;
  final String? buildPath;
  final String? webBuildPath;
  final String? symbolsPath;
  final String? dartSymbolMapPath;
  final String? commits;
  final bool? ignoreMissing;
  final String? binDir;
  final String? binPath;
  final String? sentryCliCdnUrl;
  final String? sentryCliVersion;
  final bool? legacyWebSymbolication;

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
    this.urlPrefix,
    this.waitForProcessing,
    this.logLevel,
    this.release,
    this.dist,
    this.buildPath,
    this.webBuildPath,
    this.symbolsPath,
    this.dartSymbolMapPath,
    this.commits,
    this.ignoreMissing,
    this.binDir,
    this.binPath,
    this.sentryCliCdnUrl,
    this.sentryCliVersion,
    this.legacyWebSymbolication,
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
      urlPrefix: sentryArguments['url_prefix'],
      waitForProcessing: boolFromString(sentryArguments['wait_for_processing']),
      logLevel: sentryArguments['log_level'],
      release: sentryArguments['release'],
      dist: sentryArguments['dist'],
      buildPath: sentryArguments['build_path'],
      webBuildPath: sentryArguments['web_build_path'],
      symbolsPath: sentryArguments['symbols_path'],
      dartSymbolMapPath: sentryArguments['dart_symbol_map_path'],
      commits: sentryArguments['commits'],
      ignoreMissing: boolFromString(sentryArguments['ignore_missing']),
      binDir: sentryArguments['bin_dir'],
      binPath: sentryArguments['bin_path'],
      sentryCliCdnUrl: sentryArguments['sentry_cli_cdn_url'],
      sentryCliVersion: sentryArguments['sentry_cli_version'],
      legacyWebSymbolication: boolFromString(
        sentryArguments['legacy_web_symbolication'],
      ),
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
      urlPrefix: configReader.getString('url_prefix'),
      waitForProcessing: configReader.getBool('wait_for_processing'),
      logLevel: configReader.getString('log_level'),
      release: configReader.getString('release'),
      dist: configReader.getString('dist'),
      buildPath: configReader.getString('build_path'),
      webBuildPath: configReader.getString('web_build_path'),
      symbolsPath: configReader.getString('symbols_path'),
      dartSymbolMapPath: configReader.getString('dart_symbol_map_path'),
      commits: configReader.getString('commits'),
      ignoreMissing: configReader.getBool('ignore_missing'),
      binDir: configReader.getString('bin_dir'),
      binPath: configReader.getString('bin_path'),
      sentryCliCdnUrl: configReader.getString('sentry_cli_cdn_url'),
      sentryCliVersion: configReader.getString('sentry_cli_version'),
      legacyWebSymbolication: configReader.getBool('legacy_web_symbolication'),
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
    String? envSentryCliCdnUrl = environment['SENTRYCLI_CDNURL'];
    if (envSentryCliCdnUrl?.isEmpty ?? false) {
      envSentryCliCdnUrl = null;
    }
    String? envDartSymbolMapPath = environment['SENTRY_DART_SYMBOL_MAP_PATH'];
    if (envDartSymbolMapPath?.isEmpty ?? false) {
      envDartSymbolMapPath = null;
    }
    return ConfigurationValues(
      release: envRelease,
      dist: envDist,
      sentryCliCdnUrl: envSentryCliCdnUrl,
      dartSymbolMapPath: envDartSymbolMapPath,
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
      urlPrefix: args.urlPrefix ?? file.urlPrefix,
      waitForProcessing: args.waitForProcessing ?? file.waitForProcessing,
      logLevel: args.logLevel ?? file.logLevel,
      release: platformEnv.release ?? args.release ?? file.release,
      dist: platformEnv.dist ?? args.dist ?? file.dist,
      buildPath: args.buildPath ?? file.buildPath,
      webBuildPath: args.webBuildPath ?? file.webBuildPath,
      symbolsPath: args.symbolsPath ?? file.symbolsPath,
      dartSymbolMapPath: platformEnv.dartSymbolMapPath ??
          args.dartSymbolMapPath ??
          file.dartSymbolMapPath,
      commits: args.commits ?? file.commits,
      ignoreMissing: args.ignoreMissing ?? file.ignoreMissing,
      binDir: args.binDir ?? file.binDir,
      binPath: args.binPath ?? file.binPath,
      sentryCliCdnUrl: platformEnv.sentryCliCdnUrl ??
          args.sentryCliCdnUrl ??
          file.sentryCliCdnUrl,
      sentryCliVersion: args.sentryCliVersion ?? file.sentryCliVersion,
      legacyWebSymbolication:
          args.legacyWebSymbolication ?? file.legacyWebSymbolication,
    );
  }
}
