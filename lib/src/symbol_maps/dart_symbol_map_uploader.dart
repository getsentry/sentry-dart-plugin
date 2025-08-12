import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';

import '../configuration.dart';
import '../utils/injector.dart';
import '../utils/log.dart';
import '../utils/cli_params.dart';

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

        Log.info(
            "Uploading Dart symbol map '$symbolMapPath' paired with '$debugFilePath'");

        final List<String> params = CliParams.base(config)
          ..addAll(<String>['dart-symbol-map', 'upload']);
        CliParams.addOrgAndProject(params, config);
        CliParams.addWait(params, config);
        params
          ..add(symbolMapPath)
          ..add(debugFilePath);

        final int exitCode = await _startAndForward(
          processManager: processManager,
          cliPath: config.cliPath!,
          params: params,
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
    required List<String> params,
    required String errorContext,
  }) async {
    int exitCode;
    try {
      final Process process = await processManager.start([cliPath, ...params]);

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
}
