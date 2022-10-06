import 'dart:io';
import 'dart:convert';

import 'package:process/process.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';

void main() {
  late SentryDartPlugin plugin;
  late MockProcessManager pm;

  setUp(() {
    plugin = SentryDartPlugin();
    // override process manager
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
  });

  test('no commands with no args', () async {
    final exitCode = await plugin.run([]);
    expect(exitCode, 1);
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
    commandLog.add(command.toString());
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
