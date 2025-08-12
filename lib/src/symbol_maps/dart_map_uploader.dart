import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';

import '../configuration.dart';
import '../utils/injector.dart';
import '../utils/log.dart';

/// Uploads a Dart obfuscation map paired with each provided native debug file.
///
/// For every [debugFilePaths] entry, this emits one CLI invocation equivalent to:
///
///   sentry-cli dart-symbol-map upload [--url ...] [--auth-token ...]
///   [--log-level ...] --org ... --project ... [--wait]
///   <path-to-map> <path-to-debug-file>
///
/// Stdout/stderr from the underlying process are forwarded to [Log]. A
/// non-zero exit code triggers [ExitError] (via [Log.processExitCode]).
class DartMapUploader {
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

        final List<String> params = _buildBaseParams(config)
          ..addAll(<String>['dart-symbol-map', 'upload'])
          ..addAll(_orgAndProjectParams(config))
          ..addAll(_waitParam(config))
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

  /// Builds URL/auth/log-level flags when present.
  static List<String> _buildBaseParams(Configuration config) {
    final List<String> params = <String>[];
    final String? url = _readNullable<String?>(() => config.url);
    if (url != null) {
      params
        ..add('--url')
        ..add(url);
    }
    final String? token = _readNullable<String?>(() => config.authToken);
    if (token != null) {
      params
        ..add('--auth-token')
        ..add(token);
    }
    final String? level = _readNullable<String?>(() => config.logLevel);
    if (level != null) {
      params
        ..add('--log-level')
        ..add(level);
    }
    return params;
  }

  /// Builds organization/project flags when present.
  static List<String> _orgAndProjectParams(Configuration config) {
    final List<String> params = <String>[];
    final String? org = _readNullable<String?>(() => config.org);
    if (org != null) {
      params
        ..add('--org')
        ..add(org);
    }
    final String? project = _readNullable<String?>(() => config.project);
    if (project != null) {
      params
        ..add('--project')
        ..add(project);
    }
    return params;
  }

  /// Adds --wait when configured.
  static List<String> _waitParam(Configuration config) {
    bool wait = false;
    try {
      wait = config.waitForProcessing;
    } catch (_) {
      wait = false;
    }
    return wait ? <String>['--wait'] : const <String>[];
  }

  /// Starts the process and forwards stdout/stderr to [Log]. Returns exit code.
  static Future<int> _startAndForward({
    required ProcessManager processManager,
    required String cliPath,
    required List<String> params,
    required String errorContext,
  }) async {
    int exitCode;
    try {
      final Process process =
          await processManager.start(<Object>[cliPath, ...params]);

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
      // Mirror existing behavior in the plugin: treat exceptions as failures.
      return 1;
    }
    return exitCode;
  }

  /// Safely reads a possibly-late field from [Configuration], returning null
  /// if it hasn't been initialized yet.
  static T? _readNullable<T>(T? Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }
}
