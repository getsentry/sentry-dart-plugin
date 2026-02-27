import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'package:sentry_dart_plugin/src/configuration_values.dart';
import 'package:sentry_dart_plugin/src/utils/config-reader/config_reader.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/config_file_type.dart';
import 'utils/config_formatter.dart';
import 'utils/config_writer.dart';

void main() {
  group('ctor', () {
    test("fromArguments", () {
      final arguments = [
        "--sentry-define=version=fixture-sentry-version",
        "--sentry-define=name=fixture-sentry-name",
        "--sentry-define=upload_debug_symbols=true",
        "--sentry-define=upload_source_maps=true",
        "--sentry-define=upload_sources=true",
        "--sentry-define=project=fixture-project",
        "--sentry-define=org=fixture-org",
        "--sentry-define=auth_token=fixture-auth_token",
        "--sentry-define=url=fixture-url",
        "--sentry-define=dart_symbol_map_path=fixture-dart-symbol-map.json",
        "--sentry-define=wait_for_processing=true",
        "--sentry-define=log_level=fixture-log_level",
        "--sentry-define=release=fixture-release",
        "--sentry-define=dist=fixture-dist",
        "--sentry-define=build_path=fixture-build_path",
        "--sentry-define=web_build_path=fixture-web_build_path",
        "--sentry-define=symbols_path=fixture-symbols_path",
        "--sentry-define=commits=fixture-commits",
        "--sentry-define=ignore_missing=true",
        "--sentry-define=bin_dir=fixture-bin_dir",
        "--sentry-define=sentry_cli_cdn_url=fixture-sentry_cli_cdn_url",
        "--sentry-define=sentry_cli_version=1.0.0",
        "--sentry-define=legacy_web_symbolication=true"
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.name, 'fixture-sentry-name');
      expect(sut.version, 'fixture-sentry-version');
      expect(sut.uploadDebugSymbols, isTrue);
      expect(sut.uploadSourceMaps, isTrue);
      expect(sut.uploadSources, isTrue);
      expect(sut.project, 'fixture-project');
      expect(sut.org, 'fixture-org');
      expect(sut.authToken, 'fixture-auth_token');
      expect(sut.url, 'fixture-url');
      expect(sut.dartSymbolMapPath, 'fixture-dart-symbol-map.json');
      expect(sut.waitForProcessing, isTrue);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.symbolsPath, 'fixture-symbols_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, isTrue);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.sentryCliVersion, '1.0.0');
      expect(sut.legacyWebSymbolication, isTrue);
    });

    test("fromArguments supports deprecated fields", () {
      final arguments = [
        "--sentry-define=upload_native_symbols=true",
        "--sentry-define=include_native_sources=true",
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.uploadDebugSymbols, isTrue);
      expect(sut.uploadSources, isTrue);
    });

    test("fromArguments correctly reads values containing '=' delimiter", () {
      final arguments = [
        "--sentry-define=version=fixture=version",
        "--sentry-define=name=fixture=name",
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.version, 'fixture=version');
      expect(sut.name, 'fixture=name');
    });

    test('from config reader as pubspec', () {
      final sentryPubspec = '''
      version: fixture-sentry-version
      name: fixture-sentry-name
      upload_debug_symbols: true
      upload_source_maps: true
      upload_sources: true
      url: fixture-url
      dart_symbol_map_path: fixture-dart-symbol-map.json
      wait_for_processing: true
      log_level: fixture-log_level
      release: fixture-release
      dist: fixture-dist
      build_path: fixture-build_path
      web_build_path: fixture-web_build_path
      symbols_path: fixture-symbols_path
      commits: fixture-commits
      ignore_missing: true
      bin_dir: fixture-bin_dir
      sentry_cli_cdn_url: fixture-sentry_cli_cdn_url
      sentry_cli_version: 1.0.0
      legacy_web_symbolication: true
      ''';

      FileSystem fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      final pubspecConfig = ConfigFormatter.formatConfig(
        sentryPubspec,
        ConfigFileType.pubspecYaml,
        null,
      );
      final writer = ConfigWriter(
        fs,
        'fixture-name',
      );
      writer.write(
          'fixture-version', ConfigFileType.pubspecYaml, pubspecConfig);

      final reader = ConfigReader();
      final sut = ConfigurationValues.fromReader(reader);

      expect(sut.version, 'fixture-sentry-version');
      expect(sut.name, 'fixture-sentry-name');
      expect(sut.uploadDebugSymbols, isTrue);
      expect(sut.uploadSourceMaps, isTrue);
      expect(sut.uploadSources, isTrue);
      expect(sut.project, 'p');
      expect(sut.org, 'o');
      expect(sut.authToken, 't');
      expect(sut.url, 'fixture-url');
      expect(sut.dartSymbolMapPath, 'fixture-dart-symbol-map.json');
      expect(sut.waitForProcessing, isTrue);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.symbolsPath, 'fixture-symbols_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, isTrue);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.legacyWebSymbolication, isTrue);
    });

    test('from config reader as properties', () {
      final sentryProperties = '''
      version=fixture-sentry-version
      name=fixture-sentry-name
      upload_debug_symbols=true
      upload_source_maps=true
      upload_sources=true
      url=fixture-url
      dart_symbol_map_path=fixture-dart-symbol-map.json
      wait_for_processing=true
      log_level=fixture-log_level
      release=fixture-release
      dist=fixture-dist
      build_path=fixture-build_path
      web_build_path=fixture-web_build_path
      symbols_path: fixture-symbols_path
      commits=fixture-commits
      ignore_missing=true
      bin_dir=fixture-bin_dir
      sentry_cli_cdn_url=fixture-sentry_cli_cdn_url
      sentry_cli_version=1.0.0
      ''';

      FileSystem fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      final propertiesConfig = ConfigFormatter.formatConfig(
        sentryProperties,
        ConfigFileType.sentryProperties,
        null,
      );
      final writer = ConfigWriter(
        fs,
        'fixture-name',
      );
      writer.write(
          'fixture-version', ConfigFileType.sentryProperties, propertiesConfig);

      final reader = ConfigReader();
      final sut = ConfigurationValues.fromReader(reader);

      expect(sut.version, 'fixture-sentry-version');
      expect(sut.name, 'fixture-sentry-name');
      expect(sut.uploadDebugSymbols, isTrue);
      expect(sut.uploadSourceMaps, isTrue);
      expect(sut.uploadSources, isTrue);
      expect(sut.project, 'p');
      expect(sut.org, 'o');
      expect(sut.authToken, 't');
      expect(sut.url, 'fixture-url');
      expect(sut.dartSymbolMapPath, 'fixture-dart-symbol-map.json');
      expect(sut.waitForProcessing, isTrue);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.symbolsPath, 'fixture-symbols_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, isTrue);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.sentryCliVersion, '1.0.0');
    });

    test('from config reader pubspec & properties', () {
      final sentryPubspec = '''
      version: pubspec-version
      name: pubspec-name
      upload_debug_symbols: true
      upload_source_maps: true
      ''';

      final sentryProperties = '''
      version=properties-version
      url=properties-url
      upload_debug_symbols=false
      upload_sources=true
      ''';

      FileSystem fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      final propertiesConfig = ConfigFormatter.formatConfig(
        sentryProperties,
        ConfigFileType.sentryProperties,
        null,
      );
      final propertiesWriter = ConfigWriter(fs, 'fixture-name');
      propertiesWriter.write(
        'fixture-version',
        ConfigFileType.sentryProperties,
        propertiesConfig,
      );

      final pubspecConfig = ConfigFormatter.formatConfig(
        sentryPubspec,
        ConfigFileType.pubspecYaml,
        null,
      );
      final pubspecWriter = ConfigWriter(fs, 'fixture-name');
      pubspecWriter.write(
        'fixture-version',
        ConfigFileType.pubspecYaml,
        pubspecConfig,
      );

      final reader = ConfigReader();
      final sut = ConfigurationValues.fromReader(reader);

      // string

      expect(sut.version, 'pubspec-version'); // pubspec before properties
      expect(sut.name, 'pubspec-name'); // pubspec only
      expect(sut.url, 'properties-url'); // properties only

      // bool

      expect(sut.uploadDebugSymbols, isTrue); // pubspec before properties
      expect(sut.uploadSourceMaps, isTrue); // pubspec only
      expect(sut.uploadSources, isTrue); // properties only
    });

    test("fromPlatformEnvironment", () {
      final arguments = {
        'SENTRY_RELEASE': 'fixture-release',
        'SENTRY_DIST': 'fixture-dist',
        'SENTRYCLI_CDNURL': 'fixture-sentry_cli_cdn_url',
        'SENTRY_LOG_LEVEL': 'debug',
      };

      final sut = ConfigurationValues.fromPlatformEnvironment(arguments);
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.logLevel, 'debug');
    });

    test("fromPlatformEnvironment handles empty SENTRY_LOG_LEVEL", () {
      final arguments = {
        'SENTRY_LOG_LEVEL': '',
      };

      final sut = ConfigurationValues.fromPlatformEnvironment(arguments);
      expect(sut.logLevel, isNull);
    });

    test("merged gives priority to platformEnv.logLevel over args and file",
        () {
      final platformEnv = ConfigurationValues(logLevel: 'env-log-level');
      final args = ConfigurationValues(logLevel: 'args-log-level');
      final file = ConfigurationValues(logLevel: 'file-log-level');

      final sut = ConfigurationValues.merged(
        platformEnv: platformEnv,
        args: args,
        file: file,
      );

      expect(sut.logLevel, 'env-log-level');
    });

    test("merged falls back to args.logLevel when platformEnv.logLevel is null",
        () {
      final platformEnv = ConfigurationValues();
      final args = ConfigurationValues(logLevel: 'args-log-level');
      final file = ConfigurationValues(logLevel: 'file-log-level');

      final sut = ConfigurationValues.merged(
        platformEnv: platformEnv,
        args: args,
        file: file,
      );

      expect(sut.logLevel, 'args-log-level');
    });

    test(
        "merged falls back to file.logLevel when platformEnv and args logLevel are null",
        () {
      final platformEnv = ConfigurationValues();
      final args = ConfigurationValues();
      final file = ConfigurationValues(logLevel: 'file-log-level');

      final sut = ConfigurationValues.merged(
        platformEnv: platformEnv,
        args: args,
        file: file,
      );

      expect(sut.logLevel, 'file-log-level');
    });
  });
}
