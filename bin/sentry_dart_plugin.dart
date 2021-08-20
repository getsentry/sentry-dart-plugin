import 'dart:async';

import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

/// Main class that executes the SentryDartPlugin
FutureOr<void> main(List<String> arguments) async {
  await SentryDartPlugin().run(arguments);
}
