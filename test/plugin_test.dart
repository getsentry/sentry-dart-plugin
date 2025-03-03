import 'dart:io';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
import 'package:sentry_dart_plugin/src/cli/host_platform.dart';
import 'package:sentry_dart_plugin/src/cli/setup.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';

import 'utils/config_file_type.dart';
import 'utils/config_formatter.dart';
import 'utils/config_writer.dart';

void main() {
  final plugin = SentryDartPlugin();
  late ConfigWriter configWriter;
  late MockProcessManager pm;
  late FileSystem fs;

  const cli = MockCLI.name;
  const orgAndProject = '--org o --project p';
  const name = 'name';
  const buildDir = 'build';

  /// File types from which we can read configs.
  const fileTypes = [
    ConfigFileType.pubspecYaml,
    ConfigFileType.sentryProperties,
  ];

  setUp(() {
    // override dependencies for testing
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
    fs = MemoryFileSystem.test();
    fs.directory('$buildDir/app/outputs').createSync(recursive: true);
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
    configWriter = ConfigWriter(fs, name);
  });

  for (final url in const ['http://127.0.0.1', null]) {
    for (var fileType in fileTypes) {
      group('url: $url', () {
        final commonArgs =
            '${url == null ? '' : '--url http://127.0.0.1 '}--auth-token t';

        Future<Iterable<String>> runWith(String version, String config,
            {String? customCli}) async {
          final formattedConfig =
              ConfigFormatter.formatConfig(config, fileType, url);
          configWriter.write(version, fileType, formattedConfig);

          final exitCode = await plugin.run([]);
          expect(exitCode, 0);

          final cliToUse = customCli ?? cli;
          final commonCommands = [
            if (!Platform.isWindows && customCli == null) 'chmod +x $cliToUse',
            '$cliToUse help'
          ];

          expect(pm.commandLog.take(commonCommands.length), commonCommands);
          return pm.commandLog.skip(commonCommands.length);
        }

        test('works with all configuration files', () async {
          const version = '1.0.0';
          final config = '''
            upload_debug_symbols: true
            upload_sources: true
            upload_source_maps: true
            log_level: debug
            ignore_missing: true
          ''';
          final commandLog = await runWith(version, config);
          const release = '$name@$version';

          final args = '$commonArgs --log-level debug';
          expect(commandLog, [
            '$cli $args debug-files upload $orgAndProject --include-sources $buildDir/app/outputs',
            '$cli $args releases $orgAndProject new $release',
            '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/web --ext map --ext js',
            '$cli $args releases $orgAndProject files $release upload-sourcemaps lib --ext dart --url-prefix ~/lib/',
            '$cli $args releases $orgAndProject set-commits $release --auto --ignore-missing',
            '$cli $args releases $orgAndProject finalize $release'
          ]);
        });

        test('fails without args and pubspec', () async {
          final exitCode = await plugin.run([]);
          expect(exitCode, 1);

          final commonCommands = [
            if (!Platform.isWindows) 'chmod +x $cli',
            '$cli help'
          ];
          expect(pm.commandLog, commonCommands);
        });

        test('defaults', () async {
          const version = '1.0.0';
          final commandLog = await runWith(version, '');
          const release = '$name@$version';

          expect(commandLog, [
            '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
            '$cli $commonArgs releases $orgAndProject new $release',
            '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
            '$cli $commonArgs releases $orgAndProject finalize $release'
          ]);
        });

        test('takes cli-path from binPath arg', () async {
          const version = '1.0.0';
          const customCliPath = './custom/path/sentry-local-cli';
          final config = '''
            bin_path: $customCliPath
          ''';
          final commandLog = await runWith(
            version,
            config,
            customCli: customCliPath,
          );
          const release = '$name@$version';

          expect(commandLog, [
            '$customCliPath $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
            '$customCliPath $commonArgs releases $orgAndProject new $release',
            '$customCliPath $commonArgs releases $orgAndProject set-commits $release --auto',
            '$customCliPath $commonArgs releases $orgAndProject finalize $release'
          ]);
        });

        group('commits', () {
          // https://docs.sentry.io/product/cli/releases/#sentry-cli-commit-integration
          for (final value in const [
            null, // test the implicit default
            'true',
            'auto',
            'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7',
            'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7..1e248e5e6c24b79a5c46a2e8be12cef0e41bd58d',
          ]) {
            test(value, () async {
              const version = '1.0.0';
              final config = value == null ? '' : 'commits: $value';
              final commandLog = await runWith(version, config);
              final expectedArgs =
                  (value == null || value == 'auto' || value == 'true')
                      ? '--auto'
                      : '--commit $value';

              const release = '$name@$version';

              expect(commandLog, [
                '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
                '$cli $commonArgs releases $orgAndProject new $release',
                '$cli $commonArgs releases $orgAndProject set-commits $release $expectedArgs',
                '$cli $commonArgs releases $orgAndProject finalize $release'
              ]);
            });
          }

          // if explicitly disabled
          test('false', () async {
            const version = '1.0.0';
            final commandLog = await runWith(version, 'commits: false');
            const release = '$name@$version';

            expect(commandLog, [
              '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });
        });

        group('release', () {
          test('default from name and version', () async {
            const version = '1.0.0';
            final release = '$name@$version';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/web --ext map --ext js',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('release from config overrides default', () async {
            const version = '1.0.0';
            final configRelease = 'fixture-configRelease';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli $args releases $orgAndProject files $configRelease upload-sourcemaps $buildDir/web --ext map --ext js',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });
        });

        group('dist', () {
          test('read from pubspec version', () async {
            const build = '1';
            const versionWithBuild = '1.0.0+$build';
            final release = '$name@$versionWithBuild';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
            ''';
            final commandLog = await runWith(versionWithBuild, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/web --ext map --ext js --dist $build',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('read from config release', () async {
            const version = '1.0.0';
            const build = '1';
            final configRelease = 'custom+$build';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli $args releases $orgAndProject files $configRelease upload-sourcemaps $buildDir/web --ext map --ext js --dist $build',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test('used from config and appended to release', () async {
            const version = '1.0.0';
            final configDist = 'configDist';
            final release = '$name@$version+$configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              dist: $configDist
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/web --ext map --ext js --dist $configDist',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test(
              'used from config and overriding build number from pubspec version',
              () async {
            const version = '1.0.0';
            const versionWithBuild = '$version+1';
            final configDist = 'configDist';
            final release = '$name@$version+$configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              dist: $configDist
            ''';
            final commandLog = await runWith(versionWithBuild, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/web --ext map --ext js --dist $configDist',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('used from config but not appended to config release', () async {
            const version = '1.0.0';
            final configRelease = 'fixture-configRelease';
            final configDist = 'configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
              dist: $configDist
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli $args releases $orgAndProject files $configRelease upload-sourcemaps $buildDir/web --ext map --ext js --dist $configDist',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test(
              'used from config but not replacing build/dist in config release',
              () async {
            const version = '1.0.0';
            final configRelease = 'fixture-configRelease+configDist';
            final configDist = 'configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
              dist: $configDist
              url_prefix: ~/app/
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli $args releases $orgAndProject files $configRelease upload-sourcemaps $buildDir/web --ext map --ext js --dist $configDist --url-prefix ~/app/',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test('uploads debug symbols from all known paths', () async {
            const version = '1.0.0';
            final config = 'upload_debug_symbols: true';

            final outputDirectories = [
              'app/outputs',
              'app/intermediates',
              'windows/runner/Release',
              'windows/x64/runner/Release',
              'windows/arm64/runner/Release',
              'linux/x64/release/bundle',
              'linux/arm64/release/bundle',
              'macos/Build/Products/Release',
              'macos/Build/Products/Release-demo',
              'macos/framework/Release',
              'macos/framework/Release-demo',
              'ios/iphoneos/Runner.app',
              'ios/Release-iphoneos',
              'ios/Release-anyrandomflavor-iphoneos',
              'ios/archive',
              'ios/framework/Release'
            ];
            for (final dir in outputDirectories) {
              fs
                  .directory(buildDir)
                  .childDirectory(dir)
                  .createSync(recursive: true);
            }

            final commandLog = await runWith(version, config);

            for (final dir in outputDirectories) {
              expect(
                  commandLog,
                  contains(
                      '$cli $commonArgs debug-files upload $orgAndProject $buildDir/$dir'));
            }
          });
        });
      });
    }
  }
}

class MockProcessManager implements ProcessManager {
  final commandLog = <String>[];

  @override
  bool canRun(executable, {String? workingDirectory}) => true;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<ProcessResult> run(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    return Future.value(runSync(command));
  }

  @override
  ProcessResult runSync(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    commandLog.add(command.join(' '));
    return ProcessResult(-1, 0, null, null);
  }

  @override
  Future<Process> start(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      ProcessStartMode mode = ProcessStartMode.normal}) {
    commandLog.add(command.join(' '));
    return Future.value(MockProcess());
  }
}

class MockProcess implements Process {
  @override
  Future<int> get exitCode => Future.value(0);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    throw UnimplementedError();
  }

  @override
  int get pid => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => Stream.value([]);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => Stream.value([]);
}

class MockCLI implements CLISetup {
  static const name = 'mock-cli';

  @override
  Future<String> download(
    HostPlatform platform,
    String directory,
    String cdnUrl,
    String? overrideVersion,
  ) =>
      Future.value(name);

  @override
  Future<void> check(
    HostPlatform platform,
    String path,
    String cdnUrl,
    String? overrideVersion,
  ) =>
      Future.value();
}
