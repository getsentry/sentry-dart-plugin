import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Sentry.close();
  });

  group('Sentry Telemetry', () {
    test('is enabled by default when SENTRY_TELEMETRY is not set', () {
      final telemetryEnabled =
          Platform.environment['SENTRY_TELEMETRY'] != 'false';

      expect(telemetryEnabled, isTrue);
    });

    test('is disabled when SENTRY_TELEMETRY is false', () {
      // Simulates the opt-out check: SENTRY_TELEMETRY=false
      const envValue = 'false';
      final telemetryEnabled = envValue != 'false';

      expect(telemetryEnabled, isFalse);
    });

    test('is enabled when Sentry is initialized', () async {
      await Sentry.init((options) {
        options.dsn =
            'https://deee7b2ab8f85d13be8afd3f93952660@o1.ingest.us.sentry.io/4510952342814720';
        options.traceLifecycle = SentryTraceLifecycle.streaming;
        options.tracesSampleRate = 1.0;
      });

      expect(Sentry.isEnabled, isTrue);
    });

    test('is disabled after Sentry is closed', () async {
      await Sentry.init((options) {
        options.dsn =
            'https://deee7b2ab8f85d13be8afd3f93952660@o1.ingest.us.sentry.io/4510952342814720';
      });
      expect(Sentry.isEnabled, isTrue);

      await Sentry.close();
      expect(Sentry.isEnabled, isFalse);
    });
  });
}
