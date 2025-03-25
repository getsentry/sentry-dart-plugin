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

    test("takes values from platform env config", () {
      final platformEnvConfig = ConfigurationValues(
        release: 'release-platformEnv-config',
        dist: 'dist-platformEnv-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-platformEnv-config',
      );
      final argsConfig = ConfigurationValues(
        release: 'release-args-config',
        dist: 'dist-args-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-args-config',
      );
      final fileConfig = ConfigurationValues(
        release: 'release-file-config',
        dist: 'dist-file-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-file-config',
      );

      final sut = fixture.getSut(
        platformEnvConfig: platformEnvConfig,
        argsConfig: argsConfig,
        fileConfig: fileConfig,
      );

      expect(sut.release, 'release-platformEnv-config');
      expect(sut.dist, 'dist-platformEnv-config');
      expect(sut.sentryCliCdnUrl, 'sentryCliCdnUrl-platformEnv-config');
    });

    // env config

    test("takes values from args config", () {
      final platformEnvConfig = ConfigurationValues();
      final argsConfig = ConfigurationValues(
        version: 'version-args-config',
        name: 'name-args-config',
        uploadDebugSymbols: true,
        uploadSourceMaps: true,
        uploadSources: true,
        project: 'project-args-config',
        org: 'org-args-config',
        authToken: 'auth_token-args-config',
        url: 'url-args-config',
        urlPrefix: 'url-prefix-args-config',
        waitForProcessing: true,
        logLevel: 'warning',
        release: 'release-args-config',
        dist: 'dist-args-config',
        buildPath: 'build_path-args-config',
        webBuildPath: 'web_build_path-args-config',
        symbolsPath: 'symbols_path-args-config',
        commits: 'commits-args-config',
        ignoreMissing: true,
        binDir: 'binDir-args-config',
        binPath: 'binPath-args-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-args-config',
        sentryCliVersion: '1.0.0-args-config',
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
        urlPrefix: 'url-prefix-file-config',
        waitForProcessing: false,
        logLevel: 'debug',
        release: 'release-file-config',
        dist: 'dist-file-config',
        buildPath: 'build_path-file-config',
        webBuildPath: 'web_build_path-file-config',
        symbolsPath: 'symbols_path-args-config',
        commits: 'commits-file-config',
        ignoreMissing: false,
        binDir: 'binDir-file-config',
        binPath: 'binPath-file-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-file-config',
        sentryCliVersion: '1.0.0-file-config',
      );

      final sut = fixture.getSut(
        platformEnvConfig: platformEnvConfig,
        argsConfig: argsConfig,
        fileConfig: fileConfig,
      );

      expect(sut.name, 'name-args-config');
      expect(sut.version, 'version-args-config');
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'project-args-config');
      expect(sut.org, 'org-args-config');
      expect(sut.authToken, 'auth_token-args-config');
      expect(sut.url, 'url-args-config');
      expect(sut.urlPrefix, 'url-prefix-args-config');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'warning');
      expect(sut.release, 'release-args-config');
      expect(sut.dist, 'dist-args-config');
      expect(sut.buildFilesFolder, 'build_path-args-config');
      expect(sut.symbolsFolder, 'symbols_path-args-config');
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path.join(
          sut.buildFilesFolder,
          'web_build_path-args-config',
        ),
      );
      expect(sut.commits, 'commits-args-config');
      expect(sut.ignoreMissing, true);
      expect(sut.binDir, 'binDir-args-config');
      expect(sut.binPath, 'binPath-args-config');
      expect(sut.sentryCliCdnUrl, 'sentryCliCdnUrl-args-config');
      expect(sut.sentryCliVersion, '1.0.0-args-config');
    });

    test("takes values from file config", () {
      final platformEnvConfig = ConfigurationValues();
      final argsConfig = ConfigurationValues();
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
        urlPrefix: 'url-prefix-file-config',
        waitForProcessing: true,
        logLevel: 'debug',
        release: 'release-file-config',
        dist: 'dist-file-config',
        buildPath: 'build_path-file-config',
        webBuildPath: 'web_build_path-file-config',
        symbolsPath: 'symbols_path-args-config',
        commits: 'commits-file-config',
        ignoreMissing: true,
        binDir: 'binDir-file-config',
        binPath: 'binPath-file-config',
        sentryCliCdnUrl: 'sentryCliCdnUrl-file-config',
        sentryCliVersion: '1.0.0-file-config',
      );

      final sut = fixture.getSut(
        argsConfig: argsConfig,
        fileConfig: fileConfig,
        platformEnvConfig: platformEnvConfig,
      );

      expect(sut.name, 'name-file-config');
      expect(sut.version, 'version-file-config');

      expect(sut.uploadDebugSymbols, false);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, true);
      expect(sut.project, 'project-file-config');
      expect(sut.org, 'org-file-config');
      expect(sut.authToken, 'auth_token-file-config');
      expect(sut.url, 'url-file-config');
      expect(sut.urlPrefix, 'url-prefix-file-config');
      expect(sut.waitForProcessing, true);
      expect(sut.logLevel, 'debug');
      expect(sut.release, 'release-file-config');
      expect(sut.dist, 'dist-file-config');
      expect(sut.buildFilesFolder, 'build_path-file-config');
      expect(sut.symbolsFolder, 'symbols_path-args-config');
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path
            .join(sut.buildFilesFolder, 'web_build_path-file-config'),
      );
      expect(sut.commits, 'commits-file-config');
      expect(sut.ignoreMissing, true);
      expect(sut.binDir, 'binDir-file-config');
      expect(sut.binPath, 'binPath-file-config');
      expect(sut.sentryCliCdnUrl, 'sentryCliCdnUrl-file-config');
      expect(sut.sentryCliVersion, '1.0.0-file-config');
    });

    test("falls back to default values", () {
      final envConfig = ConfigurationValues();
      final fileConfig = ConfigurationValues();
      final platformEnvConfig = ConfigurationValues();

      final sut = fixture.getSut(
        argsConfig: envConfig,
        fileConfig: fileConfig,
        platformEnvConfig: platformEnvConfig,
      );

      expect(sut.name, 'name-pubspec-config');
      expect(sut.version, 'version-pubspec-config');
      expect(sut.uploadDebugSymbols, true);
      expect(sut.uploadSourceMaps, true);
      expect(sut.uploadSources, false);
      expect(sut.commits, 'auto');
      expect(sut.ignoreMissing, false);
      expect(sut.buildFilesFolder, 'build');
      expect(
        sut.webBuildFilesFolder,
        fixture.fs.path.join(sut.buildFilesFolder, 'web'),
      );
      expect(sut.waitForProcessing, false);
      expect(sut.binDir, '.dart_tool/pub/bin/sentry_dart_plugin');
      expect(
        sut.sentryCliCdnUrl,
        'https://downloads.sentry-cdn.com/sentry-cli',
      );
    });
  });
}

class Fixture {
  Fixture(this.fs);

  FileSystem fs;

  Configuration getSut({
    required ConfigurationValues platformEnvConfig,
    required ConfigurationValues argsConfig,
    required ConfigurationValues fileConfig,
  }) {
    final pubspecConfig = ConfigFormatter.formatConfig(
      '',
      ConfigFileType.pubspecYaml,
      null,
    );
    final writer = ConfigWriter(
      fs,
      'name-pubspec-config',
    );
    writer.write(
        'version-pubspec-config', ConfigFileType.pubspecYaml, pubspecConfig);

    final configuration = Configuration();
    configuration.loadConfig(
      platformEnvConfig: platformEnvConfig,
      argsConfig: argsConfig,
      fileConfig: fileConfig,
    );
    return configuration;
  }
}
