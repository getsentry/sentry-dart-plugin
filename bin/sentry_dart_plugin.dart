import 'dart:io';
import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

/// Main class that executes the SentryDartPlugin
Future<void> main(List<String> arguments) async {
  await Sentry.init(
    (options) {
      options.dsn =
          'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';
      options.traceLifecycle = SentryTraceLifecycle.streaming;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      exitCode = await SentryDartPlugin().run(arguments);
    },
  );
  await Sentry.close();
}
