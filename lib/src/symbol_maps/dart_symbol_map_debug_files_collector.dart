import 'package:file/file.dart';
import 'package:sentry_dart_plugin/src/utils/flutter_debug_files.dart';

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
/// The function returns absolute, deduplicated paths. It enumerates the
/// configured `symbolsFolder`, `buildFilesFolder`, and other Flutter
/// search roots discovered by `enumerateDebugSearchRoots`.
Future<Set<String>> collectDebugFilesForDartMap({
  required FileSystem fs,
  required Configuration config,
}) async {
  final Set<String> foundPaths = <String>{};
  final path = fs.path;

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
        foundPaths.add(fs.file(entity.path).absolute.path);
      }
    }
  }

  Future<bool> containsAndroidSymbols(String rootPath) async {
    if (rootPath.isEmpty) return false;
    final Directory directory = fs.directory(rootPath);
    if (!await directory.exists()) return false;

    await for (final FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final String basename = fs.path.basename(entity.path);
      if (basename.startsWith('app') &&
          basename.endsWith('.symbols') &&
          !basename.contains('darwin') &&
          !basename.contains('ios')) {
        return true;
      }
    }
    return false;
  }

  Future<void> collectAppleMachOUnder(String rootPath) async {
    if (rootPath.isEmpty) return;
    final Directory dir = fs.directory(rootPath);
    if (!await dir.exists()) return;

    await for (final FileSystemEntity entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final String basename = fs.path.basename(entity.path);
      if (basename == 'App.framework.dSYM') {
        final String machOPath = fs.path.join(
          entity.path,
          'Contents',
          'Resources',
          'DWARF',
          'App',
        );
        final File machOFile = fs.file(machOPath);
        if (await machOFile.exists()) {
          foundPaths.add(machOFile.absolute.path);
        }
      }
    }
  }

  // Prefer scanning Android symbols only under the configured symbols folder.
  final List<String> androidRoots = <String>[];
  if (config.symbolsFolder.isNotEmpty &&
      await containsAndroidSymbols(config.symbolsFolder)) {
    androidRoots.add(path.normalize(config.symbolsFolder));
  } else if (config.buildFilesFolder.isNotEmpty) {
    // Fallback if symbolsFolder is not provided or does not contain any symbols.
    androidRoots.add(path.normalize(config.buildFilesFolder));
  }

  for (final String root in androidRoots) {
    await collectAndroidSymbolsUnder(root);
  }

  // Always scan the build folder for Apple Mach-O, if present.
  await collectAppleMachOUnder(config.buildFilesFolder);

  // Enumerate additional Flutter-related roots and only consider those
  // that are OUTSIDE the build folder to avoid re-traversal.
  final List<String> extraRoots = <String>[];
  await for (final String root
      in enumerateDebugSearchRoots(fs: fs, config: config)) {
    final String normalized = path.normalize(root);
    final String buildDir = path.normalize(config.buildFilesFolder);
    final bool isInsideBuild =
        normalized == buildDir || path.isWithin(buildDir, normalized);
    if (!isInsideBuild) {
      extraRoots.add(normalized);
    }
  }

  // Only Apple Mach-O discovery is relevant for these extra roots.
  for (final String root in extraRoots) {
    await collectAppleMachOUnder(root);
  }

  return foundPaths;
}
