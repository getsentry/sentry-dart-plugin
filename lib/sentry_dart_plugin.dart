import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:process/process.dart';

import 'src/configuration.dart';
import 'src/proguard/proguard_mapping.dart';
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

      if (_configuration.uploadProguard) {
        await _executeCliForProguardMapping();
      } else {
        Log.info('uploadProguard is disabled.');
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

      if (_configuration.finalizeRelease) {
        await _executeFinalizeRelease(release);
      } else {
        Log.info('Release finalization is disabled.');
      }
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

    _addWait(params);

    final fs = injector.get<FileSystem>();
    final debugSymbolPaths =
        enumerateDebugSearchRoots(fs: fs, config: _configuration);
    await for (final path in debugSymbolPaths) {
      if (await fs.directory(path).exists() || await fs.file(path).exists()) {
        await _executeAndLog('Failed to upload symbols', [...params, path]);
      }
    }

    for (final path in await _enumerateSymbolFiles()) {
      await _executeAndLog('Failed to upload symbols', [...params, path]);
    }

    await _tryUploadDartSymbolMap();

    Log.taskCompleted(taskName);
  }

  /// Uploads the Android ProGuard/R8 mappings.
  ///
  /// Each mapping is uploaded under the UUID derived from the R8 map ID in its
  /// header ([proguardUuidFromMapId]). R8 writes the same ID into the app's
  /// DEX, where the SDK reads it at runtime, so nothing has to be embedded
  /// into the app before the build. With [Configuration.proguardUuid] set, a
  /// single mapping is uploaded under that UUID instead.
  Future<void> _executeCliForProguardMapping() async {
    const taskName = 'uploading ProGuard mapping';
    Log.startingTask(taskName);

    // Like the Dart symbol map, the mapping upload is a side task: an
    // unreadable build output or a failed upload must not stop the release
    // from being created.
    try {
      await _uploadProguardMappings();
    } on Exception catch (e) {
      Log.warn('Skipping the ProGuard mapping upload: $e');
    } finally {
      Log.taskCompleted(taskName);
    }
  }

  Future<void> _uploadProguardMappings() async {
    final fs = injector.get<FileSystem>();
    final mappings = await findProguardMappings(fs: fs, config: _configuration);
    final configuredUuid = _configuration.proguardUuid?.trim() ?? '';

    if (mappings.isEmpty) {
      // Only an Android build is expected to produce a mapping; the same UUID
      // may well be configured for every platform a CI job builds.
      final isAndroidBuild = await fs
          .directory(
              fs.path.join(_configuration.buildFilesFolder, 'app', 'outputs'))
          .exists();
      if (configuredUuid.isNotEmpty && isAndroidBuild) {
        Log.warn(
            "'proguard_uuid' is set but no ProGuard mapping file was found. "
            'Is minification enabled for this build?');
      } else {
        Log.info('No ProGuard mapping file found, skipping.');
      }
    } else if (configuredUuid.isNotEmpty) {
      await _uploadProguardMappingWithConfiguredUuid(mappings, configuredUuid);
    } else {
      // Each mapping goes up under the UUID of its own R8 map ID, which the
      // SDK derives from the same ID in the app's DEX at runtime.
      final uploadedIds = <String>{};
      for (final mapping in mappings) {
        final String? mapId;
        try {
          mapId = await readProguardMapId(fs, mapping);
        } on Exception catch (e) {
          // Unreadable or not text (FileSystemException, FormatException):
          // skip it, the other variants may still be fine.
          Log.warn("Skipping ProGuard mapping '$mapping': $e");
          continue;
        }
        if (mapId == null) {
          Log.info("ProGuard mapping '$mapping' has no '# pg_map_id' (not "
              'written by R8?), skipping. Set proguard_uuid to upload it, or '
              'use the Sentry Android Gradle Plugin.');
        } else if (!uploadedIds.contains(mapId) &&
            await _uploadProguardMapping(
                mapping, proguardUuidFromMapId(mapId))) {
          // Only once it's on the server: if the upload failed, another
          // mapping with the same map ID still gets a try.
          uploadedIds.add(mapId);
        }
      }
    }
  }

  /// Uploads one mapping under the configured UUID, which the app must also
  /// report at runtime: the most recent one, or `proguard_mapping_path`.
  Future<void> _uploadProguardMappingWithConfiguredUuid(
      List<String> mappings, String uuid) async {
    if (!isValidProguardUuid(uuid)) {
      Log.error(
          "'proguard_uuid' is not a valid UUID: '$uuid'. Skipping the ProGuard mapping upload.");
      return;
    }
    if (mappings.length > 1) {
      Log.warn(
        'Found multiple ProGuard mapping files: ${mappings.join(', ')}. '
        "Uploading the most recent one, '${mappings.first}', under "
        "'proguard_uuid'. Set 'proguard_mapping_path' to choose a specific "
        "one, or unset 'proguard_uuid' to upload each under its R8 map ID.",
      );
    }
    await _uploadProguardMapping(mappings.first, uuid);
  }

  /// Returns whether the upload succeeded.
  Future<bool> _uploadProguardMapping(String mapping, String uuid) async {
    final params = <String>[];
    _setUrlAndTokenAndLog(params);
    params.add('upload-proguard');
    _addOrgAndProject(params);
    params.addAll(['--uuid', uuid, mapping]);
    try {
      return await _executeAndLog('Failed to upload ProGuard mapping', params);
    } on ExitError catch (e) {
      Log.error("Uploading ProGuard mapping '$mapping' failed with exit code "
          '${e.code}, continuing.');
      return false;
    }
  }

  Future<Set<String>> _enumerateSymbolFiles() async {
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
    return result;
  }

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
  Future<void> _tryUploadDartSymbolMap() async {
    const taskName = 'uploading Dart symbol map(s)';
    Log.startingTask(taskName);

    try {
      final fs = injector.get<FileSystem>();
      await uploadDartSymbolMap(fs: fs, config: _configuration);
    } catch (e) {
      Log.error('Dart symbol map upload failed: $e');
    } finally {
      Log.taskCompleted(taskName);
    }
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

  /// Returns every file inside [_configuration.webBuildFilesFolder] whose
  /// path ends with [extension] **and** is *not* matched by an ignore glob.
  ///
  /// The generic type `T` lets the caller decide what they want back
  /// (e.g. `String` path vs. `File` object).
  Future<List<T>> _collectWebFiles<T>({
    required String extension,
    required T Function(File) builder,
  }) async {
    final fs = injector.get<FileSystem>();
    final webDir = fs.directory(_configuration.webBuildFilesFolder);

    // Fast-fail if the directory doesn’t exist.
    if (!await webDir.exists()) {
      Log.warn(
        'Web build directory "${_configuration.webBuildFilesFolder}" does not exist, '
        'skipping $extension enumeration.',
      );
      return <T>[];
    }

    // Compile ignore globs once instead of on every iteration.
    final ignoreGlobs =
        _configuration.ignoreWebSourcePaths.map((p) => Glob(p)).toList();

    bool shouldIgnore(String absolute, String relative) =>
        ignoreGlobs.any((g) => g.matches(absolute) || g.matches(relative));

    final results = <T>[];

    await for (final entity
        in webDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final path = entity.path;
      if (!path.toLowerCase().endsWith(extension)) continue;

      final relative = fs.path
          .relative(path, from: _configuration.webBuildFilesFolder)
          .replaceAll(r'\', '/');

      if (!shouldIgnore(path, relative)) {
        results.add(builder(entity));
      } else {
        Log.info('Ignoring $relative (matched ignore_web_source_paths)');
      }
    }

    return results;
  }

  Future<List<String>> _findAllJsFilePaths() => _collectWebFiles<String>(
        extension: '.js',
        builder: (file) => file.path,
      );

  Future<List<File>> _findAllSourceMapFiles() => _collectWebFiles<File>(
        extension: '.js.map',
        builder: (file) => file.absolute,
      );

  Future<bool> _injectDebugIds() async {
    List<String> params = [];
    params.add('sourcemaps');

    // There is currently a sentry-cli bug that mutates the Flutter Web source map
    // in such a way that it becomes corrupt / invalid -> that's why we need to
    // inject each file separately instead of using a directory
    // TODO(buenaflor): in the future we should use the directory when sentry-cli is fixed
    final jsFilePaths = await _findAllJsFilePaths();
    if (jsFilePaths.isEmpty) {
      return false;
    }

    params.add('inject');
    for (final path in jsFilePaths) {
      params.add(path);
    }

    params.addAll(_baseCliParams());

    return await _executeAndLog('Failed to inject debug ids', params);
  }

  Future<void> _uploadSourceMaps(
      {required String release, required String? dist}) async {
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

    for (final ignorePattern in _configuration.ignoreWebSourcePaths) {
      params.add('--ignore');
      params.add(ignorePattern);
    }

    params.addAll(_baseCliParams());

    await _executeAndLog('Failed to sources files', params);
  }

  /// Extracts and returns a list of path prefixes to strip from source maps.
  ///
  /// The prefixes are sorted from most specific to least specific to ensure
  /// correct stripping behavior. This includes:
  /// - Paths leading up to Flutter source references
  /// - General relative path prefixes like '../', '../../', etc.
  Future<List<String>> _extractPrefixesToStrip(
      List<File> sourceMapFiles) async {
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
      ..sort((a, b) => b.split('../').length.compareTo(a.split('../').length));

    return [
      ...flutterPrefixes,
      ...sortedParentDirPrefixes,
    ];
  }

  Future<void> _executeCliForLegacySourceMaps(
      {required String release, required String? dist}) async {
    // `releases files <release> upload-sourcemaps` was removed in sentry-cli 3.
    // `sourcemaps upload --release <release>` uploads the same release-bound
    // artifacts; we simply don't inject debug ids in legacy mode.
    void addExtensionToParams(List<String> exts, List<String> params,
        String release, String folder, String? urlPrefix) {
      params.add('sourcemaps');
      params.add('upload');
      params.add('--release');
      params.add(release);
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

      _addOrgAndProject(params);
    }

    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    final params = <String>[];
    _setUrlAndTokenAndLog(params);

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

    await _executeAndLog('Failed to upload source maps', releaseJsFilesParams);

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

      await _executeAndLog(
          'Failed to upload source files', releaseDartFilesParams);
    }

    Log.taskCompleted(taskName);
  }

  Future<void> _executeCliForSourceMaps(
      {required String release, required String? dist}) async {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    final debugIdInjectionSucceeded = await _injectDebugIds();
    if (debugIdInjectionSucceeded) {
      await _uploadSourceMaps(release: release, dist: dist);
    } else {
      Log.warn('Skipping source maps upload. Could not inject debug ids.');
    }

    Log.taskCompleted(taskName);
  }

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

  Future<bool> _executeAndLog(String errorMessage, List<String> params) async {
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
      return false;
    }

    Log.processExitCode(exitCode);
    return exitCode == 0;
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
