import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/symbol_maps/dart_symbol_map_uploader.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:sentry_dart_plugin/src/utils/log.dart';

void main() {
  group('DartMapUploader.upload', () {
    late MockProcessManager pm;

    setUp(() {
      pm = MockProcessManager();
      injector.registerSingleton<ProcessManager>(() => pm, override: true);
    });

    test('emits one command per debug file with all flags', () async {
      final config = Configuration()
        ..cliPath = 'mock-cli'
        ..url = 'https://example.invalid'
        ..authToken = 'token'
        ..logLevel = 'debug'
        ..org = 'my-org'
        ..project = 'my-proj';

      final map = '/abs/path/obfuscation.map';
      final debugFiles = <String>[
        '/a/app.android-arm.symbols',
        '/b/App.framework.dSYM/Contents/Resources/DWARF/App',
      ];

      await DartSymbolMapUploader.upload(
        config: config,
        symbolMapPath: map,
        debugFilePaths: debugFiles,
      );

      expect(pm.commandLog.length, 4);
      expect(
        pm.commandLog[0],
        equals(
          'mock-cli debug-files check --json ${debugFiles[0]}',
        ),
      );
      expect(
        pm.commandLog[1],
        equals(
          'mock-cli --url https://example.invalid --auth-token token --log-level debug '
          'dart-symbol-map upload --org my-org --project my-proj '
          '$map ${debugFiles[0]}',
        ),
      );
      expect(
        pm.commandLog[2],
        equals(
          'mock-cli debug-files check --json ${debugFiles[1]}',
        ),
      );
      expect(
        pm.commandLog[3],
        equals(
          'mock-cli --url https://example.invalid --auth-token token --log-level debug '
          'dart-symbol-map upload --org my-org --project my-proj '
          '$map ${debugFiles[1]}',
        ),
      );
    });

    test('omits optional flags when not configured', () async {
      final config = Configuration()
        ..cliPath = 'mock-cli'
        ..url = null
        ..authToken = null
        ..logLevel = null
        ..org = null
        ..project = null;

      final map = '/m/map.json';
      final debugFiles = <String>['/d/file.symbols'];

      await DartSymbolMapUploader.upload(
        config: config,
        symbolMapPath: map,
        debugFilePaths: debugFiles,
      );

      expect(pm.commandLog.length, 2);
      expect(
        pm.commandLog[0],
        equals('mock-cli debug-files check --json ${debugFiles.single}'),
      );
      expect(
        pm.commandLog[1],
        equals('mock-cli dart-symbol-map upload $map ${debugFiles.single}'),
      );
    });

    test('propagates non-zero exit codes via ExitError', () async {
      // First debug-id check succeeds, then the first upload fails.
      pm.exitCodes = <int>[0, 1];

      final config = Configuration()
        ..cliPath = 'mock-cli'
        ..org = 'o'
        ..project = 'p'
        ..url = null
        ..authToken = null
        ..logLevel = null;

      final call = DartSymbolMapUploader.upload(
        config: config,
        symbolMapPath: '/map.json',
        debugFilePaths: <String>['/debug.symbols', '/ignored.second'],
      );

      await expectLater(call, throwsA(isA<ExitError>()));
      // Only the first pair of commands (check + upload) should have been issued
      // because the first upload fails and throws.
      expect(pm.commandLog.length, 2);
    });
  });
}

class MockProcessManager implements ProcessManager {
  final List<String> commandLog = <String>[];
  List<int> exitCodes = <int>[]; // optional per-start exit codes

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
      covariant Encoding? stderrEncoding = systemEncoding}) async {
    return runSync(command);
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
    final int code = exitCodes.isNotEmpty ? exitCodes.removeAt(0) : 0;
    return ProcessResult(-1, code, null, null);
  }

  @override
  Future<Process> start(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      ProcessStartMode mode = ProcessStartMode.normal}) async {
    commandLog.add(command.join(' '));
    final int code = exitCodes.isNotEmpty ? exitCodes.removeAt(0) : 0;
    return MockProcess(code);
  }
}

class MockProcess implements Process {
  final int _exitCode;
  MockProcess(this._exitCode);

  @override
  Future<int> get exitCode => Future<int>.value(_exitCode);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => false;

  @override
  int get pid => -1;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();
}
