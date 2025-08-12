import '../configuration.dart';

// TODO(buenaflor): in a future PR this should be reused in sentry_dart_plugin.dart
class CliParams {
  /// Returns URL/auth-token/log-level flags when present.
  static List<String> base(Configuration config) {
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

  /// Appends --org/--project when present.
  static void addOrgAndProject(List<String> params, Configuration config) {
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
  }

  /// Appends --wait if configured.
  static void addWaitIfNeeded(List<String> params, Configuration config) {
    bool wait = false;
    try {
      wait = config.waitForProcessing;
    } catch (_) {
      wait = false;
    }
    if (wait) {
      params.add('--wait');
    }
  }

  static T? _readNullable<T>(T? Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }
}
