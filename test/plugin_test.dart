import 'dart:io';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
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
  });

  test('fails without args and pubspec', () async {
    final exitCode = await plugin.run([]);
    expect(exitCode, 1);
    expect(pm.commandLog, const [
      'chmod +x .dart_tool/pub/bin/sentry_dart_plugin/sentry-cli',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli help'
    ]);
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
  url: http://127.0.0.1
  log_level: debug
''');
    final exitCode = await plugin.run([]);
    expect(exitCode, 0);
    expect(pm.commandLog, const [
      'chmod +x .dart_tool/pub/bin/sentry_dart_plugin/sentry-cli',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli help',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli --url http://127.0.0.1 --auth-token t --log-level debug upload-dif --include-sources --org o --project p /',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli --url http://127.0.0.1 --auth-token t --log-level debug releases --org o --project p new project@1.1.0',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli --url http://127.0.0.1 --auth-token t --log-level debug releases --org o --project p files project@1.1.0 upload-sourcemaps //build/web --ext map --ext js',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli --url http://127.0.0.1 --auth-token t --log-level debug releases --org o --project p files project@1.1.0 upload-sourcemaps / --ext dart',
      '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli --url http://127.0.0.1 --auth-token t --log-level debug releases --org o --project p finalize project@1.1.0'
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
