import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';
import 'package:sentry_dart_plugin/src/utils/cli_args.dart';

import '../configuration.dart';
import '../utils/injector.dart';
import '../utils/log.dart';

/// Uploads a Dart obfuscation map paired with each provided native debug file.
///
/// For every [debugFilePaths] entry, this emits one CLI invocation equivalent to:
///
///   sentry-cli dart-symbol-map upload [--url ...] [--auth-token ...]
///   [--log-level ...] --org ... --project ... [--wait]
///   /path-to-map /path-to-debug-file
class DartSymbolMapUploader {
  /// Uploads [symbolMapPath] for each entry in [debugFilePaths].
  ///
  /// Throws [ExitError] on the first non-zero CLI exit code.
  static Future<void> upload({
    required Configuration config,
    required String symbolMapPath,
    required Iterable<String> debugFilePaths,
  }) async {
    final ProcessManager processManager = injector.get<ProcessManager>();

    int attempted = 0;
    int succeeded = 0;
    int failed = 0;

    try {
      for (final String debugFilePath in debugFilePaths) {
        attempted++;

        final String? debugId = await _fetchDebugId(
          processManager: processManager,
          cliPath: config.cliPath!,
          debugFilePath: debugFilePath,
        );
        if (debugId != null && debugId.isNotEmpty) {
          await _prependDebugIdMarkerToMapFile(symbolMapPath, debugId);
        } else {
          Log.warn(
              'Could not resolve debug id for "$debugFilePath". Proceeding without map modification.');
        }

        Log.info(
            "Uploading Dart symbol map '$symbolMapPath' paired with '$debugFilePath'");

        final args = [
          ...config.baseArgs(),
          'dart-symbol-map',
          'upload',
          ...config.orgProjectArgs(),
          symbolMapPath,
          debugFilePath,
        ];

        final int exitCode = await _startAndForward(
          processManager: processManager,
          cliPath: config.cliPath!,
          args: args,
          errorContext: 'Failed to upload Dart symbol map for $debugFilePath',
        );

        if (exitCode == 0) {
          succeeded++;
        } else {
          failed++;
        }

        // Propagate non-zero exit code consistently with the plugin behavior.
        Log.processExitCode(exitCode);
      }
    } finally {
      Log.info(
          'Dart symbol map upload summary: attempted=$attempted, succeeded=$succeeded, failed=$failed');
    }
  }

  /// Starts the process and forwards stdout/stderr to [Log]. Returns exit code.
  /// TODO(buenaflor): eventually this should be deduplicated with the one in sentry_dart_plugin.dart
  static Future<int> _startAndForward({
    required ProcessManager processManager,
    required String cliPath,
    required List<String> args,
    required String errorContext,
  }) async {
    int exitCode;
    try {
      final Process process = await processManager.start([cliPath, ...args]);

      process.stdout.transform(utf8.decoder).listen((String data) {
        final String trimmed = data.trim();
        if (trimmed.isNotEmpty) {
          Log.info(trimmed);
        }
      });
      process.stderr.transform(utf8.decoder).listen((String data) {
        final String trimmed = data.trim();
        if (trimmed.isNotEmpty) {
          Log.error(trimmed);
        }
      });

      exitCode = await process.exitCode;
    } on Exception catch (exception) {
      Log.error('$errorContext: \n$exception');
      return 1;
    }
    return exitCode;
  }

  /// Returns the debug id for the given [debugFilePath] by invoking:
  ///   sentry-cli debug-files check --json /debug_file_path
  /// Returns null on failure.
  static Future<String?> _fetchDebugId({
    required ProcessManager processManager,
    required String cliPath,
    required String debugFilePath,
  }) async {
    try {
      final Process process = await processManager.start([
        cliPath,
        'debug-files',
        'check',
        '--json',
        debugFilePath,
      ]);

      final StringBuffer stdoutBuffer = StringBuffer();
      final StringBuffer stderrBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
      process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);

      final int code = await process.exitCode;
      if (code != 0) {
        Log.warn(
            'Failed to fetch debug id for "$debugFilePath" (exit=$code): ${stderrBuffer.toString().trim()}');
        return null;
      }

      final String output = stdoutBuffer.toString().trim();
      if (output.isEmpty) {
        Log.warn('Empty output when fetching debug id for "$debugFilePath"');
        return null;
      }

      final dynamic decoded = jsonDecode(output);
      if (decoded is! Map<String, dynamic>) {
        Log.warn('Unexpected JSON when fetching debug id for "$debugFilePath"');
        return null;
      }

      final variants = decoded['variants'];
      if (variants is List && variants.isNotEmpty) {
        final first = variants.first;
        if (first is Map && first['debug_id'] is String) {
          return first['debug_id'] as String;
        }
      }

      Log.warn('No debug id found in variants for "$debugFilePath"');
      return null;
    } catch (e) {
      Log.warn('Exception while fetching debug id for "$debugFilePath": $e');
      return null;
    }
  }

  /// Reads the Dart symbol map at [mapPath] and ensures the array starts with
  /// ["SENTRY_DEBUG_ID_MARKER", debugId]. If a previous marker is present, it
  /// will be replaced. Fails silently (with logs) on IO/JSON errors.
  static Future<void> _prependDebugIdMarkerToMapFile(
      String mapPath, String debugId) async {
    try {
      final File file = File(mapPath);
      if (!await file.exists()) {
        Log.warn(
            "Cannot modify Dart symbol map: file does not exist at '$mapPath'.");
        return;
      }

      final String raw = await file.readAsString();
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        Log.warn(
            'Cannot modify Dart symbol map: top-level JSON is not an array.');
        return;
      }

      final List<dynamic> original = List<dynamic>.from(decoded);
      List<dynamic> tail;
      if (original.isNotEmpty && original.first == 'SENTRY_DEBUG_ID_MARKER') {
        tail = original.length > 2 ? original.sublist(2) : <dynamic>[];
      } else {
        tail = original;
      }

      final List<dynamic> updated = <dynamic>[
        'SENTRY_DEBUG_ID_MARKER',
        debugId,
        ...tail,
      ];

      await file.writeAsString(jsonEncode(updated));
    } catch (e) {
      Log.warn('Failed to modify Dart symbol map before upload: $e');
    }
  }
}
