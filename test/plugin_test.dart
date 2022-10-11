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

  setUp(() {
    // override dependencies for testing
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
    fs = MemoryFileSystem.test();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
  });

  const cli = MockCLI.name;
  const orgAndProject = '--org o --project p';

  test('fails without args and pubspec', () async {
    final exitCode = await plugin.run([]);
    expect(exitCode, 1);
    expect(pm.commandLog, const ['chmod +x $cli', '$cli help']);
  });

  test('works with pubspec', () async {
    fs.file('pubspec.yaml').writeAsStringSync('''
name: project
version: 1.1.0

sentry:
  upload_native_symbols: true
  include_native_sources: true
  upload_source_maps: true
  auth_token: t
  project: p
  org: o
  url: http://127.0.0.1 # TODO: because this param affects all commands, make it a test-group argument and run all test cases with/without it.
  log_level: debug
''');
    final exitCode = await plugin.run([]);
    expect(exitCode, 0);
    const args = '--url http://127.0.0.1 --auth-token t --log-level debug';
    expect(pm.commandLog, const [
      'chmod +x $cli',
      '$cli help',
      '$cli $args upload-dif --include-sources $orgAndProject /',
      '$cli $args releases $orgAndProject new project@1.1.0',
      '$cli $args releases $orgAndProject files project@1.1.0 upload-sourcemaps /build/web --ext map --ext js',
      '$cli $args releases $orgAndProject files project@1.1.0 upload-sourcemaps / --ext dart',
      '$cli $args releases $orgAndProject finalize project@1.1.0'
    ]);
  });

  test('defaults', () async {
    fs.file('pubspec.yaml').writeAsStringSync('''
name: project
version: 1.1.0

sentry:
  auth_token: t # TODO: support not specifying this, let sentry-cli use the value it can find in its configs
  project: p
  org: o
''');
    final exitCode = await plugin.run([]);
    expect(exitCode, 0);
    expect(pm.commandLog, const [
      'chmod +x $cli',
      '$cli help',
      '$cli --auth-token t upload-dif $orgAndProject /',
    ]);
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
