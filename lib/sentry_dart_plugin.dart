import 'dart:convert';

import 'package:process/process.dart';

import 'src/configuration.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';

/// Class responsible to load the configurations and upload the
/// debug symbols and source maps
class SentryDartPlugin {
  late Configuration _configuration;

  /// SentryDartPlugin ctor. that inits the injectors
  SentryDartPlugin() {
    initInjector();
  }

  /// Method responsible to load the configurations and upload the
  /// debug symbols and source maps
  Future<int> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    try {
      await _configuration.getConfigValues(cliArguments);
      if (!_configuration.validateConfigValues()) {
        return 1;
      }

      if (_configuration.uploadDebugSymbols) {
        await _executeCliForDebugSymbols();
      } else {
        Log.info('uploadNativeSymbols is disabled.');
      }

      final release = _release;

      await _executeNewRelease(release);

      if (_configuration.uploadSourceMaps) {
        await _executeCliForSourceMaps(release);
      } else {
        Log.info('uploadSourceMaps is disabled.');
      }

      if (_configuration.commits.toLowerCase() != 'false') {
        await _executeSetCommits(release);
      } else {
        Log.info('Commit integration is disabled.');
      }

      await _executeFinalizeRelease(release);
    } on ExitError catch (e) {
      return e.code;
    }
    return 0;
  }

  Future<void> _executeCliForDebugSymbols() async {
    const taskName = 'uploading debug symbols';
    Log.startingTask(taskName);

    List<String> params = [];

    _setUrlAndTokenAndLog(params);

    params.add('debug-files');
    params.add('upload');

    _addOrgAndProject(params);

    if (_configuration.uploadSources) {
      params.add('--include-sources');
    } else {
      Log.info('includeSources is disabled, not uploading sources.');
    }

    params.add(_configuration.buildFilesFolder);

    _addWait(params);

    await _executeAndLog('Failed to upload symbols', params);

    Log.taskCompleted(taskName);
  }

  List<String> _releasesCliParams() {
    final params = <String>[];
    _setUrlAndTokenAndLog(params);
    params.add('releases');
    _addOrgAndProject(params);
    return params;
  }

  Future<void> _executeNewRelease(String release) async {
    await _executeAndLog('Failed to create a new release',
        [..._releasesCliParams(), 'new', release]);
  }

  Future<void> _executeFinalizeRelease(String release) async {
    await _executeAndLog('Failed to finalize the new release',
        [..._releasesCliParams(), 'finalize', release]);
  }

  Future<void> _executeSetCommits(String release) async {
    final params = [
      ..._releasesCliParams(),
      'set-commits',
      release,
    ];

    if (['auto', 'true', ''].contains(_configuration.commits.toLowerCase())) {
      params.add('--auto');
    } else {
      params.add('--commit');
      params.add(_configuration.commits);
    }

    if (_configuration.ignoreMissing) {
      params.add('--ignore-missing');
    }

    await _executeAndLog('Failed to set commits', params);
  }

  Future<void> _executeCliForSourceMaps(String release) async {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    List<String> params = _releasesCliParams();

    // upload source maps (js and map)
    List<String> releaseJsFilesParams = [];
    releaseJsFilesParams.addAll(params);

    _addExtensionToParams(['map', 'js'], releaseJsFilesParams, release,
        _configuration.webBuildFilesFolder);

    _addWait(releaseJsFilesParams);
    _addUrlPrefix(releaseJsFilesParams);

    await _executeAndLog('Failed to upload source maps', releaseJsFilesParams);


    if (_configuration.uploadSources) {
      // upload source files (dart)
      List<String> releaseDartFilesParams = [];
      releaseDartFilesParams.addAll(params);

      _addExtensionToParams(['dart'], releaseDartFilesParams, release,
          _configuration.buildFilesFolder);

      _addWait(releaseDartFilesParams);

      await _executeAndLog(
          'Failed to upload source files', releaseDartFilesParams);
    }

    Log.taskCompleted(taskName);
  }

  void _addUrlPrefix(List<String> releaseDartFilesParams){
    if (_configuration.urlPrefix != null) {
      if (!_configuration.urlPrefix!.startsWith("~")) {
        Log.error(
            'urlPrefix must start with ~, please update the configuration.');
        return;
      }
      releaseDartFilesParams.add('--url-prefix');
      releaseDartFilesParams.add(_configuration.urlPrefix!);
    }
  }

  void _setUrlAndTokenAndLog(List<String> params) {
    if (_configuration.url != null) {
      params.add('--url');
      params.add(_configuration.url!);
    }

    if (_configuration.authToken != null) {
      params.add('--auth-token');
      params.add(_configuration.authToken!);
    }

    if (_configuration.logLevel != null) {
      params.add('--log-level');
      params.add(_configuration.logLevel!);
    }
  }

  Future<void> _executeAndLog(String errorMessage, List<String> params) async {
    int? exitCode;

    try {
      final process = await injector
          .get<ProcessManager>()
          .start([_configuration.cliPath!, ...params]);

      process.stdout.transform(utf8.decoder).listen((data) {
        Log.info(data.trim());
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        Log.error(data.trim());
      });

      exitCode = await process.exitCode;
    } on Exception catch (exception) {
      Log.error('$errorMessage: \n$exception');
    }
    if (exitCode != null) {
      Log.processExitCode(exitCode);
    }
  }

  void _addExtensionToParams(
      List<String> exts, List<String> params, String release, String folder) {
    params.add('files');
    params.add(release);
    params.add('upload-sourcemaps');
    params.add(folder);

    for (final ext in exts) {
      params.add('--ext');
      params.add(ext);
    }

    final configDist = _configuration.dist ?? "";
    if (configDist.isNotEmpty) {
      // Don't mutate dist users provide through env or plugin config.
      params.add('--dist');
      params.add(configDist);
    } else if (release.contains('+')) {
      params.add('--dist');
      final values = release.split('+');
      params.add(values.last);
    }
  }

  String get _release {
    final configRelease = _configuration.release ?? "";
    if (configRelease.isNotEmpty) {
      // Don't mutate release users provide through env or plugin config.
      return configRelease;
    }

    var release = '';

    release = _configuration.name;

    if (!release.contains('@')) {
      release += '@${_configuration.version}';
    }

    final dist = _dist;
    if ((dist?.isNotEmpty ?? false)) {
      if (!release.contains('+')) {
        release += '+${dist!}';
      } else {
        final values = release.split('+');
        if (values.length == 2) {
          release = '${values.first}+${dist!}';
        }
      }
    }
    return release;
  }

  String? get _dist {
    if (_configuration.dist?.isNotEmpty ?? false) {
      return _configuration.dist!;
    }

    if (_configuration.version.contains('+')) {
      final values = _configuration.version.split('+');
      return values.last;
    }
    return null;
  }

  void _addWait(List<String> params) {
    if (_configuration.waitForProcessing) {
      params.add('--wait');
    }
  }

  void _addOrgAndProject(List<String> params) {
    if (_configuration.org != null) {
      params.add('--org');
      params.add(_configuration.org!);
    }

    if (_configuration.project != null) {
      params.add('--project');
      params.add(_configuration.project!);
    }
  }
}
