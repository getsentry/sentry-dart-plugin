import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/environment_configuration.dart';
import 'package:sentry_dart_plugin/src/utils/config-reader/config_reader.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/config_file_type.dart';
import 'utils/config_formatter.dart';
import 'utils/config_writer.dart';

void main() {
  group('loadConfiguration', () {
    late Fixture fixture;

    setUp(() {
      final fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      fixture = Fixture(fs);
    });

    test("takes `version` from env config", () {
      final envConfig = EnvironmentConfiguration(
        version: 'version-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.version, 'version-env-config');
    });

    test("takes `name` from env config", () {
      final envConfig = EnvironmentConfiguration(
        name: 'name-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.name, 'name-env-config');
    });

    test("takes `upload_debug_symbols` from env config", () {
      final config = '''
      upload_debug_symbols: false
      ''';
      final envConfig = EnvironmentConfiguration(
        uploadDebugSymbols: true,
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.uploadDebugSymbols, true);
    });

    test("takes `upload_source_maps` from env config", () {
      final config = '''
      upload_source_maps: false
      ''';
      final envConfig = EnvironmentConfiguration(
        uploadSourceMaps: true,
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.uploadSourceMaps, true);
    });

    test("takes `upload_sources` from env config", () {
      final config = '''
      upload_sources: false
      ''';
      final envConfig = EnvironmentConfiguration(
        uploadSources: true,
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.uploadSources, true);
    });

    test("takes `project` from env config", () {
      final envConfig = EnvironmentConfiguration(
        project: 'project-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.project, 'project-env-config');
    });

    test("takes `org` from env config", () {
      final envConfig = EnvironmentConfiguration(
        org: 'org-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.org, 'org-env-config');
    });

    test("takes `auth_token` from env config", () {
      final envConfig = EnvironmentConfiguration(
        authToken: 'auth_token-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.authToken, 'auth_token-env-config');
    });

    test("takes `url` from env config", () {
      final config = '''
      url: 'url-config'
      ''';
      final envConfig = EnvironmentConfiguration(
        url: 'url-env-config',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.url, 'url-env-config');
    });

    test("takes `wait_for_processing` from env config", () {
      final config = '''
      wait_for_processing: false
      ''';
      final envConfig = EnvironmentConfiguration(
        waitForProcessing: true,
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.waitForProcessing, true);
    });

    test("takes `log_level` from env config", () {
      final config = '''
      log_level: 'debug'
      ''';
      final envConfig = EnvironmentConfiguration(
        logLevel: 'warning',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.logLevel, 'warning');
    });

    test("takes `release` from env config", () {
      final config = '''
      release: 'release-config'
      ''';
      final envConfig = EnvironmentConfiguration(
        release: 'release-env-config',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.release, 'release-env-config');
    });

    test("takes `dist` from env config", () {
      final config = '''
      dist: 'dist-config'
      ''';
      final envConfig = EnvironmentConfiguration(
        dist: 'dist-env-config',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.dist, 'dist-env-config');
    });

    test("takes `web_build_path` from env config", () {
      final config = '''
      web_build_path: 'web_build_path-config'
      ''';
      final envConfig = EnvironmentConfiguration(
        webBuildPath: 'web_build_path-env-config',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(
          sut.webBuildFilesFolder,
          fixture.fs.path
              .join(sut.buildFilesFolder, 'web_build_path-env-config'));
    });

    test("takes `commits` from env config", () {
      final config = '''
      commits: 'commits-config'
      ''';
      final envConfig = EnvironmentConfiguration(
        commits: 'commits-env-config',
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.commits, 'commits-env-config');
    });

    test("takes `ignore_missing` from env config", () {
      final config = '''
      ignore_missing: false
      ''';
      final envConfig = EnvironmentConfiguration(
        ignoreMissing: true,
      );

      final sut = fixture.getSut(config, envConfig);
      expect(sut.ignoreMissing, true);
    });
  });
}

class Fixture {
  Fixture(this.fs);

  FileSystem fs;

  Configuration getSut(
    String config,
    EnvironmentConfiguration envConfig,
  ) {
    final formattedConfig = ConfigFormatter.formatConfig(
      config,
      ConfigFileType.pubspecYaml,
      null,
    );

    final writer = ConfigWriter(
      fs,
      'name-config',
      'version-config',
    );
    writer.write(ConfigFileType.pubspecYaml, formattedConfig);

    final reader = ConfigReader();
    final configuration = Configuration();
    configuration.loadConfig(reader, envConfig);
    return configuration;
  }
}
