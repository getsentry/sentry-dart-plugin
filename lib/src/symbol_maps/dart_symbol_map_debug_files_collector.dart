import 'package:file/file.dart';
import 'package:sentry_dart_plugin/src/utils/log.dart';

import '../configuration.dart';

/// Collects Flutter-relevant native debug file paths that should be paired
/// with a Dart symbol map for symbolication.
///
/// Policy:
/// - Android: include Flutter-generated `.symbols` files (e.g.,
///   `app.android-arm.symbols`, `app.android-arm64.symbols`, `app.android-x64.symbols`).
/// - Apple: include the Mach-O binary `App` inside
///   `App.framework.dSYM/Contents/Resources/DWARF/App`.
///
/// The function returns absolute, deduplicated paths. Android symbols are
/// discovered under the configured `symbolsFolder`. iOS dSYMs are discovered
/// under the configured `symbolsFolder` as well as the standard Flutter/Xcode
/// build roots.
Future<Set<String>> collectDebugFilesForDartMap({
  required FileSystem fs,
  required Configuration config,
}) async {
  final Set<String> foundAndroidPaths = <String>{};
  final Set<String> foundIosPaths = <String>{};
  final path = fs.path;
  final String normalizedSymbolsFolder = path.normalize(config.symbolsFolder);
  final bool shouldSearchSymbolsFolderForIos =
      config.symbolsFolder.isNotEmpty &&
          normalizedSymbolsFolder != Configuration.defaultSymbolsFolder;

  Future<void> collectAndroidSymbolsUnder(String rootPath) async {
    if (rootPath.isEmpty) return;

    final Directory directory = fs.directory(rootPath);
    if (!await directory.exists()) return;

    await for (final FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final String basename = fs.path.basename(entity.path);
      if (basename.startsWith('app') &&
          basename.endsWith('.symbols') &&
          !basename.contains('darwin') &&
          !basename.contains('ios')) {
        foundAndroidPaths.add(fs.file(entity.path).absolute.path);
      }
    }
  }

  // Android Dart symbol files are written to the configured split-debug-info
  // directory (symbolsFolder).
  final List<String> androidRoots = <String>[];
  if (config.symbolsFolder.isNotEmpty) {
    androidRoots.add(normalizedSymbolsFolder);
  }

  for (final String root in androidRoots) {
    await collectAndroidSymbolsUnder(root);
  }

  if (foundAndroidPaths.isEmpty) {
    Log.warn('No Android symbols found in the configured symbols folder.');
  }

  // iOS App.framework.dSYM may live either in the configured symbols folder
  // (for moved/downloaded artifacts) or in the default Flutter/Xcode
  // locations:
  // - build/ios
  // - <projectRoot>/ios/build (Fastlane)
  final String buildDir = config.buildFilesFolder;
  final String projectRoot = fs.currentDirectory.path;

  Future<void> collectIosAppDsymsUnderRoot(String rootPath) async {
    if (rootPath.isEmpty) return;
    final Directory directory = fs.directory(rootPath);
    if (!await directory.exists()) return;

    final String dsymSuffix = path.join(
      'App.framework.dSYM',
      'Contents',
      'Resources',
      'DWARF',
      'App',
    );

    await for (final FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final String normalized = path.normalize(entity.path);
      if (normalized.endsWith(dsymSuffix)) {
        foundIosPaths.add(fs.file(normalized).absolute.path);
      }
    }
  }

  final List<String> iosRoots = <String>[];
  if (shouldSearchSymbolsFolderForIos) {
    iosRoots.add(normalizedSymbolsFolder);
  }
  iosRoots.add(path.join(path.normalize(buildDir), 'ios'));
  iosRoots.add(path.join(projectRoot, 'ios', 'build'));

  for (final String root in iosRoots) {
    await collectIosAppDsymsUnderRoot(root);
  }

  if (foundIosPaths.isEmpty) {
    Log.warn(
        'No iOS symbols found in the configured symbols folder, build folder, or project root.');
  }

  return foundAndroidPaths.union(foundIosPaths).toSet();
}
