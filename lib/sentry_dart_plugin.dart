import 'dart:io';

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
  Future<void> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    await _configuration.getConfigValues(cliArguments);
    _configuration.validateConfigValues();

    if (_configuration.uploadNativeSymbols) {
      _executeCliForDebugSymbols();
    } else {
      Log.info('uploadNativeSymbols is disabled.');
    }

    if (_configuration.uploadSourceMaps) {
      _executeCliForSourceMaps();
    } else {
      Log.info('uploadSourceMaps is disabled.');
    }
  }

  void _executeCliForDebugSymbols() {
    const taskName = 'uploading debug symbols';
    Log.startingTask(taskName);

    List<String> params = [];

    _setUrlAndTokenAndLog(params);

    params.add('upload-dif');

    if (_configuration.includeNativeSources) {
      params.add('--include-sources');
    } else {
      Log.info('includeNativeSources is disabled, not uploading sources.');
    }

    _addOrgAndProject(params);

    params.add(_configuration.buildFilesFolder);

    _addWait(params);

    _executeAndLog('Failed to upload symbols', params);

    Log.taskCompleted(taskName);
  }

  void _executeCliForSourceMaps() {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    List<String> params = [];

    _setUrlAndTokenAndLog(params);

    params.add('releases');

    _addOrgAndProject(params);

    List<String> releaseFinalizeParams = [];
    releaseFinalizeParams.addAll(params);

    // create new release
    List<String> releaseNewParams = [];
    releaseNewParams.addAll(params);
    releaseNewParams.add('new');

    final release = _getRelease();
    releaseNewParams.add(release);

    _executeAndLog('Failed to create new release', releaseNewParams);

    // upload source maps (js and map)
    List<String> releaseJsFilesParams = [];
    releaseJsFilesParams.addAll(params);

    _addExtensionToParams(['map', 'js'], releaseJsFilesParams, release,
        _configuration.webBuildFilesFolder);

    _addWait(releaseJsFilesParams);

    _executeAndLog('Failed to upload source maps', releaseJsFilesParams);

    // upload source maps (dart)
    List<String> releaseDartFilesParams = [];
    releaseDartFilesParams.addAll(params);

    _addExtensionToParams(['dart'], releaseDartFilesParams, release,
        _configuration.buildFilesFolder);

    _addWait(releaseDartFilesParams);

    _executeAndLog('Failed to upload source maps', releaseDartFilesParams);

    // finalize new release
    releaseFinalizeParams.add('finalize');
    releaseFinalizeParams.add(release);

    _executeAndLog('Failed to create new release', releaseFinalizeParams);

    Log.taskCompleted(taskName);
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

  void _executeAndLog(String errorMessage, List<String> params) {
    ProcessResult? processResult;
    try {
      processResult = injector
          .get<ProcessManager>()
          .runSync([_configuration.cliPath!, ...params]);
    } catch (exception) {
      Log.error('$errorMessage: \n$exception');
    }
    if (processResult != null) {
      Log.processResult(processResult);
    }
  }

  void _addExtensionToParams(
      List<String> exts, List<String> params, String version, String folder) {
    params.add('files');
    params.add(version);
    params.add('upload-sourcemaps');
    params.add(folder);

    for (final ext in exts) {
      params.add('--ext');
      params.add(ext);
    }

    // TODO: add support to custom dist
    if (version.contains('+')) {
      params.add('--dist');
      final values = version.split('+');
      params.add(values.last);
    }
  }

  String _getRelease() {
    return '${_configuration.name}@${_configuration.version}';
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
