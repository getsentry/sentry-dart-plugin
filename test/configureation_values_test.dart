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
        "--sentry-define=version=fixture-version",
        "--sentry-define=name=fixture-name",
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
        "--sentry-define=web_build_path=fixture-web_build_path",
        "--sentry-define=commits=fixture-commits",
        "--sentry-define=ignore_missing=true",
      ];
      final sut = ConfigurationValues.fromArguments(arguments);
      expect(sut.name, 'fixture-name');
      expect(sut.version, 'fixture-version');
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
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, true);
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

    test('from config reader', () {
      final config = '''
      name: fixture-name
      version: fixture-version
      upload_debug_symbols: true
      upload_source_maps: true
      upload_sources: true
      url: fixture-url
      wait_for_processing: true
      log_level: fixture-log_level
      release: fixture-release
      dist: fixture-dist
      web_build_path: fixture-web_build_path
      commits: fixture-commits
      ignore_missing: true
      ''';

      FileSystem fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      final pubspecConfig = ConfigFormatter.formatConfig(
        config,
        ConfigFileType.pubspecYaml,
        null,
      );
      final writer = ConfigWriter(
        fs,
        'fixture-name',
        'fixture-version',
      );
      writer.write(ConfigFileType.pubspecYaml, pubspecConfig);

      final reader = ConfigReader();
      final sut = ConfigurationValues.fromReader(reader);
      expect(sut.name, 'fixture-name');
      expect(sut.version, 'fixture-version');
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
      expect(sut.webBuildPath, 'fixture-web_build_path');
      expect(sut.commits, 'fixture-commits');
      expect(sut.ignoreMissing, true);
    });

    test("fromPlatformEnvironment", () {
      final arguments = {
        'SENTRY_RELEASE': 'fixture-release',
        'SENTRY_DIST': 'fixture-dist',
      };

      final sut = ConfigurationValues.fromPlatformEnvironment(arguments);
      expect(sut.release, 'fixture-release');
      expect(sut.dist, 'fixture-dist');
    });
  });
}
