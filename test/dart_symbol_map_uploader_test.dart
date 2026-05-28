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

    test('emits one upload command per debug file with configured options',
        () async {
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

      await DartSymbolMapUploader.addDebugIdMarkerAndUpload(
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
          'mock-cli --auth-token token --log-level debug '
          'dart-symbol-map upload --org my-org --project my-proj '
          '$map ${debugFiles[0]}',
        ),
      );
      expect(pm.environmentLog[1], {'SENTRY_URL': 'https://example.invalid'});
      expect(
        pm.commandLog[2],
        equals(
          'mock-cli debug-files check --json ${debugFiles[1]}',
        ),
      );
      expect(
        pm.commandLog[3],
        equals(
          'mock-cli --auth-token token --log-level debug '
          'dart-symbol-map upload --org my-org --project my-proj '
          '$map ${debugFiles[1]}',
        ),
      );
      expect(pm.environmentLog[3], {'SENTRY_URL': 'https://example.invalid'});
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

      await DartSymbolMapUploader.addDebugIdMarkerAndUpload(
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
      expect(pm.environmentLog[1], isNull);
    });

    test('waits for debug-id stdout before uploading each map', () async {
      final mapFile = await _createTempMapFile();
      final uploadedMapContents = <String>[];
      pm.handleStart = (List<Object> command) async {
        if (command.contains('dart-symbol-map')) {
          uploadedMapContents.add(
            await File(command[command.length - 2].toString()).readAsString(),
          );
          return MockProcess(0);
        }

        final bool isArm64 = command.last.toString().contains('arm64');
        return MockProcess(
          0,
          stdoutText:
              _debugCheckJson(isArm64 ? 'debug-id-arm64' : 'debug-id-arm'),
          stdoutDelay:
              isArm64 ? const Duration(milliseconds: 20) : Duration.zero,
          exitCodeDelay:
              isArm64 ? Duration.zero : const Duration(milliseconds: 20),
        );
      };

      await DartSymbolMapUploader.addDebugIdMarkerAndUpload(
        config: _minimalConfig(),
        symbolMapPath: mapFile.path,
        debugFilePaths: <String>[
          '/debug/app.android-arm.symbols',
          '/debug/app.android-arm64.symbols',
        ],
      );

      expect(uploadedMapContents, <String>[
        _mapWithDebugId('debug-id-arm'),
        _mapWithDebugId('debug-id-arm64'),
      ]);
      // The marker is only needed for upload and must not remain on the
      // user-provided obfuscation map after all uploads finish.
      expect(
          await mapFile.readAsString(), jsonEncode(<String>['symbol', 'name']));
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

      final call = DartSymbolMapUploader.addDebugIdMarkerAndUpload(
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

Configuration _minimalConfig() => Configuration()
  ..cliPath = 'mock-cli'
  ..org = 'o'
  ..project = 'p'
  ..url = null
  ..authToken = null
  ..logLevel = null;

Future<File> _createTempMapFile() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'sentry-dart-symbol-map-test-',
  );
  addTearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final mapFile = File(
    '${tempDir.path}${Platform.pathSeparator}obfuscation_map.json',
  );
  await mapFile.writeAsString(jsonEncode(<String>['symbol', 'name']));
  return mapFile;
}

String _debugCheckJson(String debugId) => jsonEncode(<String, Object>{
      'variants': <Map<String, String>>[
        <String, String>{'debug_id': debugId},
      ],
    });

String _mapWithDebugId(String debugId) => jsonEncode(<String>[
      'SENTRY_DEBUG_ID_MARKER',
      debugId,
      'symbol',
      'name',
    ]);

class MockProcessManager implements ProcessManager {
  final List<String> commandLog = <String>[];
  final List<Map<String, String>?> environmentLog = <Map<String, String>?>[];
  List<int> exitCodes = <int>[]; // optional per-start exit codes
  Future<Process> Function(List<Object> command)? handleStart;

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
    environmentLog.add(
        environment == null ? null : Map<String, String>.from(environment));
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
    environmentLog.add(
        environment == null ? null : Map<String, String>.from(environment));
    if (handleStart != null) {
      return handleStart!(command);
    }

    final int code = exitCodes.isNotEmpty ? exitCodes.removeAt(0) : 0;
    return MockProcess(code);
  }
}

class MockProcess implements Process {
  final int _exitCode;
  final String stdoutText;
  final String stderrText;
  final Duration stdoutDelay;
  final Duration stderrDelay;
  final Duration exitCodeDelay;

  MockProcess(
    this._exitCode, {
    this.stdoutText = '',
    this.stderrText = '',
    this.stdoutDelay = Duration.zero,
    this.stderrDelay = Duration.zero,
    this.exitCodeDelay = Duration.zero,
  });

  @override
  Future<int> get exitCode async {
    if (exitCodeDelay != Duration.zero) {
      await Future<void>.delayed(exitCodeDelay);
    }
    return _exitCode;
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => false;

  @override
  int get pid => -1;

  @override
  Stream<List<int>> get stderr => _delayedTextStream(stderrText, stderrDelay);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => _delayedTextStream(stdoutText, stdoutDelay);

  Stream<List<int>> _delayedTextStream(String text, Duration delay) async* {
    if (delay != Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (text.isNotEmpty) {
      yield utf8.encode(text);
    }
  }
}
