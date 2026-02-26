import 'dart:convert';

import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:sentry/sentry.dart';

import 'src/configuration.dart';
import 'src/utils/flutter_debug_files.dart';
import 'src/symbol_maps/dart_symbol_map.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';
import 'src/utils/extensions.dart';

/// Class responsible to load the configurations and upload the
/// debug symbols and source maps
class SentryDartPlugin {
  late Configuration _configuration;
  final symbolFileRegexp = RegExp(r'[/\\]app[^/\\]+.*\.(dSYM|symbols)$');

  /// SentryDartPlugin ctor. that inits the injectors
  SentryDartPlugin() {
    initInjector();
  }

  /// Method responsible to load the configurations and upload the
  /// debug symbols and source maps
  Future<int> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    return Sentry.startSpan('Plugin Execution', (span) async {
      try {
        await _configuration.getConfigValues(cliArguments);
        if (!await _configuration.validateConfigValues()) {
          return 1;
        }

        // Not setting other attributes due to possible PII
        span.setAttributes({
          'config.upload_debug_symbols':
              SentryAttribute.bool(_configuration.uploadDebugSymbols),
          'config.upload_source_maps':
              SentryAttribute.bool(_configuration.uploadSourceMaps),
          'config.upload_sources':
              SentryAttribute.bool(_configuration.uploadSources),
          'config.wait_for_processing':
              SentryAttribute.bool(_configuration.waitForProcessing),
          'config.commits': SentryAttribute.string(_configuration.commits),
          'config.ignore_missing':
              SentryAttribute.bool(_configuration.ignoreMissing),
          'config.legacy_web_symbolication':
              SentryAttribute.bool(_configuration.legacyWebSymbolication),
          'config.sentry_cli_version':
              SentryAttribute.string(_configuration.sentryCliVersion ?? ''),
        });

        if (_configuration.uploadDebugSymbols) {
          await _executeCliForDebugSymbols();
        } else {
          Log.info('uploadNativeSymbols is disabled.');
        }

        final release = _release;
        final dist = _dist;

        await _executeNewRelease(release);

        if (_configuration.uploadSourceMaps) {
          if (_configuration.legacyWebSymbolication) {
            await _executeCliForLegacySourceMaps(release: release, dist: dist);
          } else {
            await _executeCliForSourceMaps(release: release, dist: dist);
          }
        } else {
          Log.info('uploadSourceMaps is disabled.');
        }

        if (_configuration.commits.toLowerCase() != 'false') {
          await _executeSetCommits(release);
        } else {
          Log.info('Commit integration is disabled.');
        }

        await _executeFinalizeRelease(release);
      } on ExitError catch (e, stackTrace) {
        await Sentry.captureException(e, stackTrace: stackTrace);
        return e.code;
      }
      return 0;
    });
  }

  Future<void> _executeCliForDebugSymbols() async =>
      Sentry.startSpan('Upload Debug Symbols', (span) async {
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

        _addWait(params);

        final fs = injector.get<FileSystem>();
        final debugSymbolPaths =
            enumerateDebugSearchRoots(fs: fs, config: _configuration);
        await for (final path in debugSymbolPaths) {
          if (await fs.directory(path).exists() ||
              await fs.file(path).exists()) {
            await _executeAndLog('debug-files upload',
                'Failed to upload symbols', [...params, path]);
          }
        }

        for (final path in await _enumerateSymbolFiles()) {
          await _executeAndLog('debug-files upload', 'Failed to upload symbols',
              [...params, path]);
        }

        await _tryUploadDartSymbolMap();

        Log.taskCompleted(taskName);
      });

  Future<Set<String>> _enumerateSymbolFiles() async =>
      Sentry.startSpan('Enumerate Symbol Files', (span) async {
        final result = <String>{};
        final fs = injector.get<FileSystem>();

        if (_configuration.symbolsFolder.isNotEmpty) {
          final symbolsRootDir = fs.directory(_configuration.symbolsFolder);
          if (await symbolsRootDir.exists()) {
            await for (final entry in symbolsRootDir.find(symbolFileRegexp)) {
              result.add(entry.path);
            }
          }
        }

        // for backward compatibility, also check the build dir if it has been
        // configured with a different path.
        if (_configuration.buildFilesFolder != _configuration.symbolsFolder) {
          final symbolsRootDir = fs.directory(_configuration.buildFilesFolder);
          if (await symbolsRootDir.exists()) {
            await for (final entry in symbolsRootDir.find(symbolFileRegexp)) {
              result.add(entry.path);
            }
          }
        }

        span.setAttributes({
          'files_found': SentryAttribute.int(result.length),
        });

        return result;
      });

  List<String> _baseCliParams({bool addReleases = false}) {
    final params = <String>[];
    if (addReleases) {
      params.add('releases');
    }
    _addOrgAndProject(params);
    return params;
  }

  List<String> _releasesCliParams() {
    final params = <String>[];
    _setUrlAndTokenAndLog(params);
    params.addAll(_baseCliParams(addReleases: true));
    return params;
  }

  /// Upload Dart symbol map(s) if configured.
  /// This is needed to symbolicate Flutter issue titles for obfuscated builds.
  Future<void> _tryUploadDartSymbolMap() async =>
      Sentry.startSpan('Upload Dart Symbol Map', (span) async {
        const taskName = 'uploading Dart symbol map(s)';
        Log.startingTask(taskName);

        try {
          final fs = injector.get<FileSystem>();
          await uploadDartSymbolMap(fs: fs, config: _configuration);
        } catch (e, stackTrace) {
          Log.error('Dart symbol map upload failed: $e');
          await Sentry.captureException(e, stackTrace: stackTrace);
        } finally {
          Log.taskCompleted(taskName);
        }
      });

  Future<void> _executeNewRelease(String release) async =>
      Sentry.startSpan('Create Release', (span) async {
        await _executeAndLog('releases new', 'Failed to create a new release',
            [..._releasesCliParams(), 'new', release]);
      });

  Future<void> _executeFinalizeRelease(String release) async =>
      Sentry.startSpan('Finalize Release', (span) async {
        await _executeAndLog(
            'releases finalize',
            'Failed to finalize the new release',
            [..._releasesCliParams(), 'finalize', release]);
      });

  Future<void> _executeSetCommits(String release) async =>
      Sentry.startSpan('Set Commits', (span) async {
        final params = [
          ..._releasesCliParams(),
          'set-commits',
          release,
        ];

        final commitsMode = _configuration.commits.toLowerCase();
        if (['auto', 'true', ''].contains(commitsMode)) {
          params.add('--auto');
        } else {
          params.add('--commit');
          params.add(_configuration.commits);
        }

        span.setAttributes({
          'commits_mode': SentryAttribute.string(commitsMode),
        });

        if (_configuration.ignoreMissing) {
          params.add('--ignore-missing');
        }

        await _executeAndLog(
            'releases set-commits', 'Failed to set commits', params);
      });

  Future<List<String>> _findAllJsFilePaths() async {
    final List<String> jsFiles = [];
    final fs = injector.get<FileSystem>();
    final webDir = fs.directory(_configuration.webBuildFilesFolder);

    if (await webDir.exists()) {
      await for (final entity
          in webDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.js')) {
          jsFiles.add(entity.path);
        }
      }
    } else {
      Log.warn(
        'Web build directory "${_configuration.webBuildFilesFolder}" does not exist, skipping JS file enumeration.',
      );
    }
    return jsFiles;
  }

  Future<List<File>> _findAllSourceMapFiles() async {
    final List<File> sourceMapFiles = [];
    final fs = injector.get<FileSystem>();
    final webDir = fs.directory(_configuration.webBuildFilesFolder);

    if (await webDir.exists()) {
      await for (final entity
          in webDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.js.map')) {
          sourceMapFiles.add(entity.absolute);
        }
      }
    } else {
      Log.warn(
        'Web build directory "${_configuration.webBuildFilesFolder}" does not exist, skipping source map file enumeration.',
      );
    }
    return sourceMapFiles;
  }

  Future<bool> _injectDebugIds() async =>
      Sentry.startSpan('Inject Debug IDs', (span) async {
        List<String> params = [];
        params.add('sourcemaps');

        // There is currently a sentry-cli bug that mutates the Flutter Web source map
        // in such a way that it becomes corrupt / invalid -> that's why we need to
        // inject each file separately instead of using a directory
        // TODO(buenaflor): in the future we should use the directory when sentry-cli is fixed
        final jsFilePaths = await _findAllJsFilePaths();
        if (jsFilePaths.isEmpty) {
          span.setAttributes({
            'js_files_found': SentryAttribute.int(0),
          });
          return false;
        }

        span.setAttributes({
          'js_files_found': SentryAttribute.int(jsFilePaths.length),
        });

        params.add('inject');
        for (final path in jsFilePaths) {
          params.add(path);
        }

        params.addAll(_baseCliParams());

        return _executeAndLog(
            'sourcemaps inject', 'Failed to inject debug ids', params);
      });

  Future<void> _uploadSourceMaps(
          {required String release, required String? dist}) async =>
      Sentry.startSpan('Upload Source Map Files', (span) async {
        List<String> params = [];

        _setUrlAndTokenAndLog(params);
        params.add('sourcemaps');
        params.add('upload');
        params.add('--release');
        params.add(release);
        if (dist != null) {
          params.add('--dist');
          params.add(dist);
        }
        _addWait(params);
        _addUrlPrefix(params);
        params.add(_configuration.webBuildFilesFolder);
        params.add('--ext');
        params.add('js');
        params.add('--ext');
        params.add('map');

        final sourceMapFiles = await _findAllSourceMapFiles();
        final prefixesToStrip = await _extractPrefixesToStrip(sourceMapFiles);

        if (prefixesToStrip.isEmpty) {
          Log.info('No prefixes to strip found in source maps.');
        }

        for (final prefix in prefixesToStrip) {
          params.add('--strip-prefix');
          params.add(prefix);
        }

        if (_configuration.uploadSources) {
          // In the sourcemap dart source files are prefixed with /lib - we'd have to
          // add the --url-prefix ~/lib however this would be applied to all files - even the source map -
          // and not only the dart source files meaning symbolication would not work correctly
          // TODO(buenaflor): revisit this approach when we can add --url-prefixes to specific files
          params.add('./');
          params.add('--ext');
          params.add('dart');
        }

        params.addAll(_baseCliParams());

        await _executeAndLog(
            'sourcemaps upload', 'Failed to sources files', params);
      });

  /// Extracts and returns a list of path prefixes to strip from source maps.
  ///
  /// The prefixes are sorted from most specific to least specific to ensure
  /// correct stripping behavior. This includes:
  /// - Paths leading up to Flutter source references
  /// - General relative path prefixes like '../', '../../', etc.
  Future<List<String>> _extractPrefixesToStrip(
          List<File> sourceMapFiles) async =>
      Sentry.startSpan('Extract Prefixes To Strip', (span) async {
        final Set<String> flutterPrefixes = {};
        final Set<String> parentDirPrefixes = {};
        final parentDirPattern = RegExp(r'^(?:\.\./)+');
        const flutterFragment = '/flutter/packages/flutter/lib/src/';

        for (final sourceMapFile in sourceMapFiles) {
          late final Map<String, dynamic> sourceMap;
          try {
            final content = await sourceMapFile.readAsString();
            sourceMap = jsonDecode(content) as Map<String, dynamic>;
          } catch (e) {
            Log.warn(
                'Prefix Extraction: could not decode source map file ${sourceMapFile.path}');
            continue;
          }

          final sources = sourceMap['sources'];
          if (sources is! List) {
            Log.info(
                'Prefix Extraction: no sources found in source map file ${sourceMapFile.path}');
            continue;
          }

          for (final entry in sources.whereType<String>()) {
            final index = entry.indexOf(flutterFragment);
            if (index > 0) {
              flutterPrefixes.add(entry.substring(0, index));
            }
          }

          for (final entry in sources.whereType<String>()) {
            final match = parentDirPattern.firstMatch(entry);
            if (match != null) {
              final prefix = match.group(0)!;
              // Each ../ segment is 3 characters long.
              final matchCount = prefix.length ~/ 3;
              parentDirPrefixes.add('../' * matchCount);
            }
          }
        }

        final sortedParentDirPrefixes = parentDirPrefixes.toList()
          ..sort(
              (a, b) => b.split('../').length.compareTo(a.split('../').length));

        final result = [
          ...flutterPrefixes,
          ...sortedParentDirPrefixes,
        ];

        span.setAttributes({
          'source_map_files_parsed': SentryAttribute.int(sourceMapFiles.length),
          'prefixes_found': SentryAttribute.int(result.length),
        });

        return result;
      });

  Future<void> _executeCliForLegacySourceMaps(
          {required String release, required String? dist}) async =>
      Sentry.startSpan('Upload Source Maps', (span) async {
        span.setAttributes({
          'legacy': SentryAttribute.bool(true),
        });

        void addExtensionToParams(List<String> exts, List<String> params,
            String release, String folder, String? urlPrefix) {
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

          if (urlPrefix != null) {
            params.add("--url-prefix");
            params.add(urlPrefix);
          }
        }

        const taskName = 'uploading source maps';
        Log.startingTask(taskName);

        final params = <String>[];
        _setUrlAndTokenAndLog(params);
        params.add('releases');
        _addOrgAndProject(params);

        // upload source maps (js and map)
        List<String> releaseJsFilesParams = [];
        releaseJsFilesParams.addAll(params);

        addExtensionToParams(
          ['map', 'js'],
          releaseJsFilesParams,
          release,
          _configuration.webBuildFilesFolder,
          null,
        );

        _addWait(releaseJsFilesParams);
        _addUrlPrefix(releaseJsFilesParams);

        await _executeAndLog('releases files upload-sourcemaps',
            'Failed to upload source maps', releaseJsFilesParams);

        if (_configuration.uploadSources) {
          // upload source files (dart)
          List<String> releaseDartFilesParams = [];
          releaseDartFilesParams.addAll(params);

          addExtensionToParams(
            ['dart'],
            releaseDartFilesParams,
            release,
            'lib',
            '~/lib/',
          );

          _addWait(releaseDartFilesParams);

          await _executeAndLog('releases files upload-sourcemaps',
              'Failed to upload source files', releaseDartFilesParams);
        }

        Log.taskCompleted(taskName);
      });

  Future<void> _executeCliForSourceMaps(
          {required String release, required String? dist}) async =>
      Sentry.startSpan('Upload Source Maps', (span) async {
        span.setAttributes({
          'legacy': SentryAttribute.bool(false),
        });

        const taskName = 'uploading source maps';
        Log.startingTask(taskName);

        final debugIdInjectionSucceeded = await _injectDebugIds();
        if (debugIdInjectionSucceeded) {
          await _uploadSourceMaps(release: release, dist: dist);
        } else {
          Log.warn('Skipping source maps upload. Could not inject debug ids.');
        }

        Log.taskCompleted(taskName);
      });

  void _addUrlPrefix(List<String> releaseDartFilesParams) {
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

  Future<bool> _executeAndLog(
      String commandName, String errorMessage, List<String> params) async {
    return Sentry.startSpan('Execute Sentry CLI', (span) async {
      span.setAttributes({
        'cli_command': SentryAttribute.string(commandName),
      });
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
      } on Exception catch (exception, stackTrace) {
        Log.error('$errorMessage: \n$exception');
        await Sentry.captureException(exception, stackTrace: stackTrace);
        return false;
      }

      span.setAttributes({
        'exit_code': SentryAttribute.int(exitCode),
      });

      Log.processExitCode(exitCode);
      return exitCode == 0;
    });
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
