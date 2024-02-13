import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/configuration_values.dart';
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

    // env config

    test("takes `version` from env config", () {
      final envConfig = ConfigurationValues(
        version: 'version-env-config',
      );

      final sut = fixture.getSut(envConfig, '');
      expect(sut.version, 'version-env-config');
    });

    test("takes `name` from env config", () {
      final envConfig = ConfigurationValues(
        name: 'name-env-config',
      );

      final sut = fixture.getSut(envConfig, '');
      expect(sut.name, 'name-env-config');
    });

    test("takes `upload_debug_symbols` from env config", () {
      final envConfig = ConfigurationValues(
        uploadDebugSymbols: true,
      );
      final fileConfig = '''
      upload_debug_symbols: false
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.uploadDebugSymbols, true);
    });

    test("takes `upload_source_maps` from env config", () {
      final envConfig = ConfigurationValues(
        uploadSourceMaps: true,
      );
      final fileConfig = '''
      upload_source_maps: false
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.uploadSourceMaps, true);
    });

    test("takes `upload_sources` from env config", () {
      final envConfig = ConfigurationValues(
        uploadSources: true,
      );
      final fileConfig = '''
      upload_sources: false
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.uploadSources, true);
    });

    test("takes `project` from env config", () {
      final envConfig = ConfigurationValues(
        project: 'project-env-config',
      );

      final sut = fixture.getSut(envConfig, '');
      expect(sut.project, 'project-env-config');
    });

    test("takes `org` from env config", () {
      final envConfig = ConfigurationValues(
        org: 'org-env-config',
      );

      final sut = fixture.getSut(envConfig, '');
      expect(sut.org, 'org-env-config');
    });

    test("takes `auth_token` from env config", () {
      final envConfig = ConfigurationValues(
        authToken: 'auth_token-env-config',
      );

      final sut = fixture.getSut(envConfig, '');
      expect(sut.authToken, 'auth_token-env-config');
    });

    test("takes `url` from env config", () {
      final envConfig = ConfigurationValues(
        url: 'url-env-config',
      );
      final fileConfig = '''
      url: 'url-config'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.url, 'url-env-config');
    });

    test("takes `wait_for_processing` from env config", () {
      final envConfig = ConfigurationValues(
        waitForProcessing: true,
      );
      final fileConfig = '''
      wait_for_processing: false
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.waitForProcessing, true);
    });

    test("takes `log_level` from env config", () {
      final envConfig = ConfigurationValues(
        logLevel: 'warning',
      );
      final fileConfig = '''
      log_level: 'debug'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.logLevel, 'warning');
    });

    test("takes `release` from env config", () {
      final envConfig = ConfigurationValues(
        release: 'release-env-config',
      );
      final fileConfig = '''
      release: 'release-config'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.release, 'release-env-config');
    });

    test("takes `dist` from env config", () {
      final envConfig = ConfigurationValues(
        dist: 'dist-env-config',
      );
      final fileConfig = '''
      dist: 'dist-config'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.dist, 'dist-env-config');
    });

    test("takes `web_build_path` from env config", () {
      final envConfig = ConfigurationValues(
        webBuildPath: 'web_build_path-env-config',
      );
      final fileConfig = '''
      web_build_path: 'web_build_path-config'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(
          sut.webBuildFilesFolder,
          fixture.fs.path
              .join(sut.buildFilesFolder, 'web_build_path-env-config'));
    });

    test("takes `commits` from env config", () {
      final envConfig = ConfigurationValues(
        commits: 'commits-env-config',
      );
      final fileConfig = '''
      commits: 'commits-config'
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.commits, 'commits-env-config');
    });

    test("takes `ignore_missing` from env config", () {
      final envConfig = ConfigurationValues(
        ignoreMissing: true,
      );
      final fileConfig = '''
      ignore_missing: false
      ''';

      final sut = fixture.getSut(envConfig, fileConfig);
      expect(sut.ignoreMissing, true);
    });
  });
}

class Fixture {
  Fixture(this.fs);

  FileSystem fs;

  Configuration getSut(
    ConfigurationValues envConfig,
    String fileConfig,
  ) {
    final formattedConfig = ConfigFormatter.formatConfig(
      fileConfig,
      ConfigFileType.pubspecYaml,
      null,
    );

    final writer = ConfigWriter(
      fs,
      'name-config',
      'version-config',
    );
    writer.write(ConfigFileType.pubspecYaml, formattedConfig);

    final configuration = Configuration();
    configuration.loadConfig(
      envConfig: envConfig,
      fileConfig: ConfigurationValues.fromReader(ConfigReader()),
      platformEnvConfig: ConfigurationValues(),
    );
    return configuration;
  }
}
