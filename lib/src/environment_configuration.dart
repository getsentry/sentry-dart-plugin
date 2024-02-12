class EnvironmentConfiguration {
  final String? version;
  final String? name;

  final bool? uploadDebugSymbols;
  final bool? uploadSourceMaps;
  final bool? uploadSources;
  final String? project;
  final String? org;
  final String? authToken;
  final String? url;
  final bool? waitForProcessing;
  final String? logLevel;
  final String? release;
  final String? dist;
  final String? webBuildPath;
  final String? commits;
  final bool? ignoreMissing;

  EnvironmentConfiguration({
    this.version,
    this.name,
    this.uploadDebugSymbols,
    this.uploadSourceMaps,
    this.uploadSources,
    this.project,
    this.org,
    this.authToken,
    this.url,
    this.waitForProcessing,
    this.logLevel,
    this.release,
    this.dist,
    this.webBuildPath,
    this.commits,
    this.ignoreMissing,
  });

  factory EnvironmentConfiguration.fromEnvironment() {
    const version = String.fromEnvironment('version');
    const name = String.fromEnvironment('name');

    const uploadDebugSymbols = String.fromEnvironment('upload_debug_symbols');
    const uploadSourceMaps = String.fromEnvironment('upload_source_maps');
    const uploadSources = String.fromEnvironment('upload_sources');
    const project = String.fromEnvironment('project');
    const org = String.fromEnvironment('org');
    const authToken = String.fromEnvironment('auth_token');
    const url = String.fromEnvironment('url');
    const waitForProcessing = String.fromEnvironment('wait_for_processing');
    const logLevel = String.fromEnvironment('log_level');
    const release = String.fromEnvironment('release');
    const dist = String.fromEnvironment('dist');
    const webBuildPath = String.fromEnvironment('web_build_path');
    const commits = String.fromEnvironment('commits');
    const ignoreMissing = String.fromEnvironment('ignore_missing');
    return EnvironmentConfiguration(
      version: version != "" ? version : null,
      name: name != "" ? name : null,
      uploadDebugSymbols: uploadDebugSymbols == "true"
          ? true
          : uploadDebugSymbols == "false"
              ? false
              : null,
      uploadSourceMaps: uploadSourceMaps == "true"
          ? true
          : uploadSourceMaps == "false"
              ? false
              : null,
      uploadSources: uploadSources == "true"
          ? true
          : uploadSources == "false"
              ? false
              : null,
      project: project != "" ? project : null,
      org: org != "" ? org : null,
      authToken: authToken != "" ? authToken : null,
      url: url != "" ? url : null,
      waitForProcessing: waitForProcessing == "true"
          ? true
          : waitForProcessing == "false"
              ? false
              : null,
      logLevel: logLevel != "" ? logLevel : null,
      release: release != "" ? release : null,
      dist: dist != "" ? dist : null,
      webBuildPath: webBuildPath != "" ? webBuildPath : null,
      commits: commits != "" ? commits : null,
      ignoreMissing: ignoreMissing == "true"
          ? true
          : ignoreMissing == "false"
              ? false
              : null,
    );
  }
}
