import 'dart:io';
import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

/// Main class that executes the SentryDartPlugin
Future<void> main(List<String> arguments) async {
  await Sentry.init(
    (options) {
      options.dsn = 'TODO: add DSN';
    },
    appRunner: () async {
      exitCode = await SentryDartPlugin().run(arguments);
    },
  );
}
