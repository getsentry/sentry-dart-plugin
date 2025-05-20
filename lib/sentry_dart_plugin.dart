import 'dart:convert';

import 'package:file/file.dart';
import 'package:process/process.dart';
import 'package:sentry_dart_plugin/src/utils/extensions.dart';

import 'src/configuration.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';

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

    _addWait(params);

    final fs = injector.get<FileSystem>();
    final debugSymbolPaths = _enumerateDebugSymbolPaths(fs);
    await for (final path in debugSymbolPaths) {
      if (await fs.directory(path).exists() || await fs.file(path).exists()) {
        await _executeAndLog('Failed to upload symbols', [...params, path]);
      }
    }

    for (final path in await _enumerateSymbolFiles()) {
      await _executeAndLog('Failed to upload symbols', [...params, path]);
    }

    Log.taskCompleted(taskName);
  }

  Stream<String> _enumerateDebugSymbolPaths(FileSystem fs) async* {
    final buildDir = _configuration.buildFilesFolder;

    // Android (apk, appbundle)
    yield '$buildDir/app/outputs';
    yield '$buildDir/app/intermediates';

    // Windows
    for (final subdir in ['', '/x64', '/arm64']) {
      yield '$buildDir/windows$subdir/runner/Release';
    }
    // TODO we should delete this once we have windows symbols collected automatically.
    // Related to https://github.com/getsentry/sentry-dart-plugin/issues/173
    yield 'windows/flutter/ephemeral/flutter_windows.dll.pdb';

    // Linux
    for (final subdir in ['/x64', '/arm64']) {
      yield '$buildDir/linux$subdir/release/bundle';
    }

    // macOS
    yield '$buildDir/macos/Build/Products/Release';

    // macOS (macOS-framework)
    yield '$buildDir/macos/framework/Release';

    // iOS
    yield '$buildDir/ios/iphoneos/Runner.app';
    if (await fs.directory('$buildDir/ios').exists()) {
      final regexp = RegExp(r'^Release(-.*)?-iphoneos$');
      yield* fs
          .directory('$buildDir/ios')
          .list()
          .where((v) => regexp.hasMatch(v.basename))
          .map((e) => e.path);
    }

    // iOS (ipa)
    yield '$buildDir/ios/archive';

    // iOS (ios-framework)
    yield '$buildDir/ios/framework/Release';
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

  List<String> _baseCliParams({bool includeRelease = false}) {
    final params = <String>[];
    if (includeRelease) {
      params.add('releases');
    }
    _addOrgAndProject(params);
    return params;
  }

  List<String> _releasesCliParams() {
    final params = <String>[];
    _setUrlAndTokenAndLog(params);
    params.addAll(_baseCliParams(includeRelease: true));
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

  Future<void> _injectDebugIds() async {
    List<String> params = [];
    params.add('sourcemaps');

    // There is currently a sentry-cli bug that mutates the Flutter Web source map
    // in such a way that it becomes corrupt / invalid -> that's why we need to
    // inject each file separately instead of using a directory
    // TODO(buenaflor): in the future we should use the directory when sentry-cli is fixed
    final jsFilePaths = await _findAllJsFilePaths();
    params.add('inject');
    for (final path in jsFilePaths) {
      params.add(path);
    }

    params.addAll(_baseCliParams());

    await _executeAndLog('Failed to inject debug ids', params);
  }

  Future<void> _uploadSourceMaps() async {
    List<String> params = [];
    _setUrlAndTokenAndLog(params);
    params.add('sourcemaps');
    params.add('upload');
    _addWait(params);
    _addUrlPrefix(params);
    params.add(_configuration.webBuildFilesFolder);
    params.add('--ext');
    params.add('js');
    params.add('--ext');
    params.add('map');

    final sourceMapFiles = await _findAllSourceMapFiles();
    final prefixesToStrip = await _extractPrefixesToStrip(sourceMapFiles);
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
    await _executeAndLog('Failed to sources files', params);
  }

  /// Reads available source maps and returns the list of prefixes that should
  /// be stripped from the source maps. This step is important to make the
  /// paths clearer and less verbose.
  ///
  /// Prefixes must be ordered from most specific to least specific,
  /// because they are applied sequentially. If a general prefix like '../'
  /// is applied first, it may strip parts of the path that a more specific
  /// prefix (e.g. '../../') would otherwise match, effectively preventing
  /// the latter from being applied. This ensures correct and non-overlapping
  /// path stripping behavior in sentry-cli.
  ///
  /// Returns a list of sorted prefixes.
  Future<Set<String>> _extractPrefixesToStrip(List<File> sourceMapFiles) async {
    final Set<String> prefixes = {};
    final Set<String> parentDirs = {};
    final parentDirPattern = RegExp(r'^(?:\.\./)+');
    const flutterFragment = '/flutter/packages/flutter/lib/src/';

    for (final sourceMapFile in sourceMapFiles) {
      late final Map<String, dynamic> sourceMap;
      try {
        final content = await sourceMapFile.readAsString();
        sourceMap = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        continue;
      }

      final sources = sourceMap['sources'];
      if (sources is! List) {
        continue;
      }

      for (final entry in sources.whereType<String>()) {
        final index = entry.indexOf(flutterFragment);
        if (index > 0) {
          prefixes.add(entry.substring(0, index));
        }
      }

      for (final entry in sources.whereType<String>()) {
        final match = parentDirPattern.firstMatch(entry);
        if (match != null) {
          final prefix = match.group(0)!;
          // Each ../ segment is 3 characters long.
          final matchCount = prefix.length ~/ 3;
          parentDirs.add('../' * matchCount);
        }
      }
    }

    final sortedParentDirs = parentDirs.toList()
      ..sort((a, b) => b.split('../').length.compareTo(a.split('../').length));
    prefixes.addAll(sortedParentDirs);

    return prefixes;
  }

  Future<void> _executeCliForSourceMaps(String release) async {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    await _injectDebugIds();
    await _uploadSourceMaps();

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
