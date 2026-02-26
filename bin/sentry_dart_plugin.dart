import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

/// Main class that executes the SentryDartPlugin
Future<void> main(List<String> arguments) async {
  final telemetryEnabled = isTelemetryEnabled(Platform.environment);

  if (telemetryEnabled) {
    await Sentry.init((options) {
      options.dsn =
          'https://deee7b2ab8f85d13be8afd3f93952660@o1.ingest.us.sentry.io/4510952342814720';
      options.traceLifecycle = SentryTraceLifecycle.streaming;
      options.tracesSampleRate = 1.0;
    });
  }

  try {
    exitCode = await SentryDartPlugin().run(arguments);
  } catch (error, stackTrace) {
    // Workaround until the following issue is fixed: https://github.com/getsentry/sentry-dart/issues/3541
    // Sentry currently swallows errors
    await Sentry.captureException(error, stackTrace: stackTrace);
    rethrow;
  } finally {
    // Wait for the spans to be sent, close should actually flush them but it seems to be a bug.
    // https://github.com/getsentry/sentry-dart-plugin/issues/383
    await Future.delayed(const Duration(seconds: 5));
    await Sentry.close();
  }
}
