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

void main() {
  final plugin = SentryDartPlugin();
  late MockProcessManager pm;
  late FileSystem fs;

  const cli = MockCLI.name;
  const orgAndProject = '--org o --project p';
  const project = 'project';
  const version = '1.1.0';
  const release = '$project@$version';
  const buildDir = '/subdir';

  setUp(() {
    // override dependencies for testing
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
    fs = MemoryFileSystem.test();
    fs.currentDirectory = fs.directory(buildDir)..createSync();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
  });

  Future<Iterable<String>> runWith(String config) async {
    // properly indent the configuration for the `sentry` section in the yaml
    final configIndented =
        config.trim().split('\n').map((l) => '  ${l.trim()}').join('\n');

    fs.file('pubspec.yaml').writeAsStringSync('''
name: $project
version: $version

sentry:
  auth_token: t # TODO: support not specifying this, let sentry-cli use the value it can find in its configs
  project: p
  org: o
$configIndented
''');

    final exitCode = await plugin.run([]);
    expect(exitCode, 0);
    expect(pm.commandLog.take(2), const ['chmod +x $cli', '$cli help']);
    return pm.commandLog.skip(2);
  }

  test('fails without args and pubspec', () async {
    final exitCode = await plugin.run([]);
    expect(exitCode, 1);
    expect(pm.commandLog, const ['chmod +x $cli', '$cli help']);
  });

  test('works with pubspec', () async {
    // TODO: because `url` param affects all commands, make it a test-group argument and run all test cases with/without it.
    final commandLog = await runWith('''
      upload_native_symbols: true
      include_native_sources: true
      upload_source_maps: true
      url: http://127.0.0.1
      log_level: debug
    ''');
    const args =
        '--url http://127.0.0.1 --auth-token t --log-level debug $orgAndProject';
    expect(commandLog, const [
      '$cli $args upload-dif --include-sources $buildDir',
      '$cli $args releases new $release',
      '$cli $args releases files $release upload-sourcemaps $buildDir/build/web --ext map --ext js',
      '$cli $args releases files $release upload-sourcemaps $buildDir --ext dart',
      '$cli $args releases set-commits $release --auto',
      '$cli $args releases finalize $release'
    ]);
  });

  test('defaults', () async {
    final commandLog = await runWith('');
    const args = '--auth-token t $orgAndProject';
    expect(commandLog, const [
      '$cli $args upload-dif $buildDir',
      '$cli $args releases new $release',
      '$cli $args releases set-commits $release --auto',
      '$cli $args releases finalize $release'
    ]);
  });

  group('commits', () {
    const args = '--auth-token t $orgAndProject';

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
        expect(commandLog, [
          '$cli $args upload-dif $buildDir',
          '$cli $args releases new $release',
          '$cli $args releases set-commits $release $expectedArgs',
          '$cli $args releases finalize $release'
        ]);
      });
    }

    // if explicitly disabled
    test('false', () async {
      final commandLog = await runWith('commits: false');
      expect(commandLog, [
        '$cli $args upload-dif $buildDir',
        '$cli $args releases new $release',
        '$cli $args releases finalize $release'
      ]);
    });
  });
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
    throw UnimplementedError();
  }
}

class MockCLI implements CLISetup {
  static const name = 'mock-cli';

  @override
  Future<String> download(HostPlatform platform) => Future.value(name);
}
