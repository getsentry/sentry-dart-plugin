import '../configuration.dart';

// TODO(buenaflor): in a future PR this should be reused in other parts of the code
extension SentryCliArgs on Configuration {
  List<String> baseArgs() => [
        if (url != null) ...['--url', url!],
        if (authToken != null) ...['--auth-token', authToken!],
        if (logLevel != null) ...['--log-level', logLevel!],
      ];

  List<String> orgProjectArgs() => [
        if (org != null) ...['--org', org!],
        if (project != null) ...['--project', project!],
      ];

  List<String> waitArgs() => [if (waitForProcessing) '--wait'];
}
