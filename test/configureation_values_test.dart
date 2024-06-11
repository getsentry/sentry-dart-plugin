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
        "--sentry-define=wait_for_processing=true",
        "--sentry-define=log_level=fixture-log_level",
        "--sentry-define=release=fixture-release",
        "--sentry-define=dist=fixture-dist",
        "--sentry-define=build_path=fixture-build_path",
        "--sentry-define=web_build_path=fixture-web_build_path",
        "--sentry-define=commits=fixture-commits",
        "--sentry-define=ignore_missing=true",
        "--sentry-define=bin_dir=fixture-bin_dir",
        "--sentry-define=sentry_cli_cdn_url=fixture-sentry_cli_cdn_url",
        "--sentry-define=sentry_cli_version=1.0.0",
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.name, 'fixture-sentry-name');
      expect(sut.version, 'fixture-sentry-version');
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'fixture-project');
      expect(sut.org, 'fixture-org');
      expect(sut.authToken, 'fixture-auth_token');
      expect(sut.url, 'fixture-url');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, true);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.sentryCliVersion, '1.0.0');
    });

    test("fromArguments supports deprecated fields", () {
      final arguments = [
        "--sentry-define=upload_native_symbols=true",
        "--sentry-define=include_native_sources=true",
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSources, true);
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
      wait_for_processing: true
      log_level: fixture-log_level
      release: fixture-release
      dist: fixture-dist
      build_path: fixture-build_path
      web_build_path: fixture-web_build_path
      commits: fixture-commits
      ignore_missing: true
      bin_dir: fixture-bin_dir
      sentry_cli_cdn_url: fixture-sentry_cli_cdn_url
      sentry_cli_version: 1.0.0
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
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'p');
      expect(sut.org, 'o');
      expect(sut.authToken, 't');
      expect(sut.url, 'fixture-url');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, true);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
    });

    test('from config reader as properties', () {
      final sentryProperties = '''
      version=fixture-sentry-version
      name=fixture-sentry-name   
      upload_debug_symbols=true
      upload_source_maps=true
      upload_sources=true
      url=fixture-url
      wait_for_processing=true
      log_level=fixture-log_level
      release=fixture-release
      dist=fixture-dist
      build_path=fixture-build_path
      web_build_path=fixture-web_build_path
      commits=fixture-commits
      ignore_missing=true
      bin_dir=fixture-bin_dir
      sentry_cli_cdn_url=fixture-sentry_cli_cdn_url
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
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'p');
      expect(sut.org, 'o');
      expect(sut.authToken, 't');
      expect(sut.url, 'fixture-url');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'fixture-log_level');
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.buildPath, 'fixture-build_path');
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, true);
      expect(sut.binDir, 'fixture-bin_dir');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
      expect(sut.sentryCliVersion, '1.0.0');
    });

    test("fromPlatformEnvironment", () {
      final arguments = {
        'SENTRY_RELEASE': 'fixture-release',
        'SENTRY_DIST': 'fixture-dist',
        'SENTRYCLI_CDNURL': 'fixture-sentry_cli_cdn_url',
      };

      final sut = ConfigurationValues.fromPlatformEnvironment(arguments);
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
      expect(sut.sentryCliCdnUrl, 'fixture-sentry_cli_cdn_url');
    });
  });
}
