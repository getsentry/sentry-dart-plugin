import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

/// Main class that executes the SentryDartPlugin
Future<void> main(List<String> arguments) async {
  await Sentry.init((options) {
    options.dsn =
        'https://deee7b2ab8f85d13be8afd3f93952660@o1.ingest.us.sentry.io/4510952342814720';
    options.traceLifecycle = SentryTraceLifecycle.streaming;
    options.tracesSampleRate = 1.0;
  });

  try {
    exitCode = await SentryDartPlugin().run(arguments);
  } catch (error, stackTrace) {
    // Workaround until the following issue is fixed: https://github.com/getsentry/sentry-dart/issues/3541
    // Sentry currently swallows errors
    await Sentry.captureException(error, stackTrace: stackTrace);
    await Sentry.close();
    rethrow;
  }

  await Sentry.close();
}
