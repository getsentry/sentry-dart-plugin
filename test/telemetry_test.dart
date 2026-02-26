import 'package:sentry/sentry.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Sentry.close();
  });

  group('Sentry Telemetry', () {
    test('is enabled by default when SENTRY_TELEMETRY is not set', () {
      expect(isTelemetryEnabled({}), isTrue);
    });

    test('is enabled when SENTRY_TELEMETRY is any value other than false', () {
      expect(isTelemetryEnabled({'SENTRY_TELEMETRY': 'true'}), isTrue);
      expect(isTelemetryEnabled({'SENTRY_TELEMETRY': '1'}), isTrue);
      expect(isTelemetryEnabled({'SENTRY_TELEMETRY': ''}), isTrue);
    });

    test('is disabled when SENTRY_TELEMETRY is false', () {
      expect(isTelemetryEnabled({'SENTRY_TELEMETRY': 'false'}), isFalse);
    });
  });
}
