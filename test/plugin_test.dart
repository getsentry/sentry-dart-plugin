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

  const project = 'project';
  const version = '1.1.0';

  const buildDir = '/subdir';

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
    fs.currentDirectory = fs.directory(buildDir)..createSync();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
    configWriter = ConfigWriter(fs, project, version);
  });

  for (final url in const ['http://127.0.0.1', null]) {
    for (var fileType in fileTypes) {
      group('url: $url', () {
        final commonArgs =
            '${url == null ? '' : '--url http://127.0.0.1 '}--auth-token t';
        final commonCommands = [
          if (!Platform.isWindows) 'chmod +x $cli',
          '$cli help'
        ];

        Future<Iterable<String>> runWith(String config) async {
          final formattedConfig =
              ConfigFormatter.formatConfig(config, fileType, url);
          configWriter.write(fileType, formattedConfig);

          final exitCode = await plugin.run([]);
          expect(exitCode, 0);
          expect(pm.commandLog.take(commonCommands.length), commonCommands);
          return pm.commandLog.skip(commonCommands.length);
        }

        test('works with all configuration files', () async {
          final config = '''
            upload_debug_symbols: true
            upload_sources: true
            upload_source_maps: true
            log_level: debug
            ignore_missing: true
          ''';
          final commandLog = await runWith(config);
          const release = '$project@$version';

          final args = '$commonArgs --log-level debug';
          expect(commandLog, [
            '$cli $args debug-files upload $orgAndProject --include-sources $buildDir',
            '$cli $args releases $orgAndProject new $release',
            '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/build/web --ext map --ext js',
            '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir --ext dart',
            '$cli $args releases $orgAndProject set-commits $release --auto --ignore-missing',
            '$cli $args releases $orgAndProject finalize $release'
          ]);
        });

        test('fails without args and pubspec', () async {
          final exitCode = await plugin.run([]);
          expect(exitCode, 1);
          expect(pm.commandLog, commonCommands);
        });

        test('defaults', () async {
          final commandLog = await runWith('');
          const release = '$project@$version';

          expect(commandLog, [
            '$cli $commonArgs debug-files upload $orgAndProject $buildDir',
            '$cli $commonArgs releases $orgAndProject new $release',
            '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
            '$cli $commonArgs releases $orgAndProject finalize $release'
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
              final commandLog =
                  await runWith(value == null ? '' : 'commits: $value');
              final expectedArgs =
                  (value == null || value == 'auto' || value == 'true')
                      ? '--auto'
                      : '--commit $value';
              const release = '$project@$version';

              expect(commandLog, [
                '$cli $commonArgs debug-files upload $orgAndProject $buildDir',
                '$cli $commonArgs releases $orgAndProject new $release',
                '$cli $commonArgs releases $orgAndProject set-commits $release $expectedArgs',
                '$cli $commonArgs releases $orgAndProject finalize $release'
              ]);
            });
          }

          // if explicitly disabled
          test('false', () async {
            final commandLog = await runWith('commits: false');
            const release = '$project@$version';

            expect(commandLog, [
              '$cli $commonArgs debug-files upload $orgAndProject $buildDir',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });
        });

        group('custom releases and dists', () {
          test('release with build number (dist)', () async {
            final dist = 'myDist';
            final release = 'myRelease@myVersion+$dist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $release
            ''';
            final commandLog = await runWith(config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir/build/web --ext map --ext js --dist $dist',
              '$cli $args releases $orgAndProject files $release upload-sourcemaps $buildDir --ext dart --dist $dist',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('custom release with a dist in it', () async {
            final dist = 'myDist';
            final release = 'myRelease@myVersion+$dist';

            final customDist = 'anotherDist';
            final customRelease = 'myRelease@myVersion+$customDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $release
              dist: $customDist
            ''';
            final commandLog = await runWith(config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $customRelease',
              '$cli $args releases $orgAndProject files $customRelease upload-sourcemaps $buildDir/build/web --ext map --ext js --dist $customDist',
              '$cli $args releases $orgAndProject files $customRelease upload-sourcemaps $buildDir --ext dart --dist $customDist',
              '$cli $args releases $orgAndProject set-commits $customRelease --auto',
              '$cli $args releases $orgAndProject finalize $customRelease'
            ]);
          });

          test('custom release with a custom dist', () async {
            final dist = 'myDist';
            final release = 'myRelease@myVersion';
            final fullRelease = '$release+$dist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $release
              dist: $dist
            ''';
            final commandLog = await runWith(config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $fullRelease',
              '$cli $args releases $orgAndProject files $fullRelease upload-sourcemaps $buildDir/build/web --ext map --ext js --dist $dist',
              '$cli $args releases $orgAndProject files $fullRelease upload-sourcemaps $buildDir --ext dart --dist $dist',
              '$cli $args releases $orgAndProject set-commits $fullRelease --auto',
              '$cli $args releases $orgAndProject finalize $fullRelease'
            ]);
          });

          test('custom dist', () async {
            final dist = 'myDist';
            const release = '$project@$version';
            final fullRelease = '$release+$dist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              dist: $dist
            ''';
            final commandLog = await runWith(config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $fullRelease',
              '$cli $args releases $orgAndProject files $fullRelease upload-sourcemaps $buildDir/build/web --ext map --ext js --dist $dist',
              '$cli $args releases $orgAndProject files $fullRelease upload-sourcemaps $buildDir --ext dart --dist $dist',
              '$cli $args releases $orgAndProject set-commits $fullRelease --auto',
              '$cli $args releases $orgAndProject finalize $fullRelease'
            ]);
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
  Future<String> download(HostPlatform platform) => Future.value(name);
}
