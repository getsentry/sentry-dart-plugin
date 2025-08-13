import '../configuration.dart';

// TODO(buenaflor): in a future PR this should be reused in other parts of the code
class CliParams {
  /// Returns URL/auth-token/log-level flags when present.
  static List<String> base(Configuration config) {
    final List<String> params = <String>[];
    final String? url = config.url;
    if (url != null) {
      params
        ..add('--url')
        ..add(url);
    }
    final String? token = config.authToken;
    if (token != null) {
      params
        ..add('--auth-token')
        ..add(token);
    }
    final String? level = config.logLevel;
    if (level != null) {
      params
        ..add('--log-level')
        ..add(level);
    }
    return params;
  }

  /// Appends --org/--project when present.
  static void addOrgAndProject(List<String> params, Configuration config) {
    final String? org = config.org;
    if (org != null) {
      params
        ..add('--org')
        ..add(org);
    }
    final String? project = config.project;
    if (project != null) {
      params
        ..add('--project')
        ..add(project);
    }
  }

  /// Appends --wait if configured.
  static void addWait(List<String> params, Configuration config) {
    final bool wait = config.waitForProcessing;
    if (wait) {
      params.add('--wait');
    }
  }
}
