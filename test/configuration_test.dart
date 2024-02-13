import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/configuration_values.dart';
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

    test("takes values from env config", () {
      final envConfig = ConfigurationValues(
        version: 'version-env-config',
        name: 'name-env-config',
        uploadDebugSymbols: true,
        uploadSourceMaps: true,
        uploadSources: true,
        project: 'project-env-config',
        org: 'org-env-config',
        authToken: 'auth_token-env-config',
        url: 'url-env-config',
        waitForProcessing: true,
        logLevel: 'warning',
        release: 'release-env-config',
        dist: 'dist-env-config',
        webBuildPath: 'web_build_path-env-config',
        commits: 'commits-env-config',
        ignoreMissing: true,
      );
      final fileConfig = ConfigurationValues(
        version: 'version-file-config',
        name: 'name-file-config',
        uploadDebugSymbols: false,
        uploadSourceMaps: false,
        uploadSources: false,
        project: 'project-file-config',
        org: 'org-file-config',
        authToken: 'auth_token-file-config',
        url: 'url-file-config',
        waitForProcessing: false,
        logLevel: 'debug',
        release: 'release-file-config',
        dist: 'dist-file-config',
        webBuildPath: 'web_build_path-file-config',
        commits: 'commits-file-config',
        ignoreMissing: false,
      );
      final platformEnvConfig = ConfigurationValues(
        release: 'release-platformEnv-config',
        dist: 'dist-platformEnv-config',
      );

      final sut = fixture.getSut(envConfig, fileConfig, platformEnvConfig);

      expect(sut.name, 'name-env-config');
      expect(sut.version, 'version-env-config');
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'project-env-config');
      expect(sut.org, 'org-env-config');
      expect(sut.authToken, 'auth_token-env-config');
      expect(sut.url, 'url-env-config');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'warning');
      expect(sut.release, 'release-env-config');
      expect(sut.dist, 'dist-env-config');
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path.join(sut.buildFilesFolder, 'web_build_path-env-config'),
      );
      expect(sut.commits, 'commits-env-config');
      expect(sut.ignoreMissing, true);
    });

    test("takes values from file config", () {
      final envConfig = ConfigurationValues();
      final fileConfig = ConfigurationValues(
        version: 'version-file-config',
        name: 'name-file-config',
        uploadDebugSymbols: false,
        uploadSourceMaps: true,
        uploadSources: true,
        project: 'project-file-config',
        org: 'org-file-config',
        authToken: 'auth_token-file-config',
        url: 'url-file-config',
        waitForProcessing: true,
        logLevel: 'debug',
        release: 'release-file-config',
        dist: 'dist-file-config',
        webBuildPath: 'web_build_path-file-config',
        commits: 'commits-file-config',
        ignoreMissing: true,
      );
      final platformEnvConfig = ConfigurationValues(
        release: 'release-platformEnv-config',
        dist: 'dist-platformEnv-config',
      );

      final sut = fixture.getSut(envConfig, fileConfig, platformEnvConfig);

      expect(sut.name, 'name-file-config');
      expect(sut.version, 'version-file-config');
      expect(sut.uploadDebugSymbols, false);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'project-file-config');
      expect(sut.org, 'org-file-config');
      expect(sut.authToken, 'auth_token-file-config');
      expect(sut.url, 'url-file-config');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'debug');
      expect(sut.release, 'release-file-config');
      expect(sut.dist, 'dist-file-config');
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path
            .join(sut.buildFilesFolder, 'web_build_path-file-config'),
      );
      expect(sut.commits, 'commits-file-config');
      expect(sut.ignoreMissing, true);
    });

    test("takes values from platform env config", () {
      final envConfig = ConfigurationValues();
      final fileConfig = ConfigurationValues();
      final platformEnvConfig = ConfigurationValues(
        release: 'release-platformEnv-config',
        dist: 'dist-platformEnv-config',
      );

      final sut = fixture.getSut(envConfig, fileConfig, platformEnvConfig);

      expect(sut.release, 'release-platformEnv-config');
      expect(sut.dist, 'dist-platformEnv-config');
    });

    test("falls back to default values", () {
      final envConfig = ConfigurationValues();
      final fileConfig = ConfigurationValues();
      final platformEnvConfig = ConfigurationValues();

      final sut = fixture.getSut(envConfig, fileConfig, platformEnvConfig);

      expect(sut.name, 'name-pubspec-config');
      expect(sut.version, 'version-pubspec-config');
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, false);
      expect(sut.uploadSources, false);
      expect(sut.commits, 'auto');
      expect(sut.ignoreMissing, false);
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path.join(sut.buildFilesFolder, 'build/web'),
      );
      expect(sut.waitForProcessing, false);
    });
  });
}

class Fixture {
  Fixture(this.fs);

  FileSystem fs;

  Configuration getSut(
    ConfigurationValues envConfig,
    ConfigurationValues fileConfig,
    ConfigurationValues platformEnvConfig,
  ) {
    final pubspecConfig = ConfigFormatter.formatConfig(
      '',
      ConfigFileType.pubspecYaml,
      null,
    );
    final writer = ConfigWriter(
      fs,
      'name-pubspec-config',
      'version-pubspec-config',
    );
    writer.write(ConfigFileType.pubspecYaml, pubspecConfig);

    final configuration = Configuration();
    configuration.loadConfig(
      envConfig: envConfig,
      fileConfig: fileConfig,
      platformEnvConfig: platformEnvConfig,
    );
    return configuration;
  }
}
