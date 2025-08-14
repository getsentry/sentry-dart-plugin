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

  // No recursive Apple scan needed. We only care about the Mach-O at
  // <base>/App.framework.dSYM/Contents/Resources/DWARF/App. For roots that
  // end with 'Runner.app', the dSYM lives next to it, so we probe the parent
  // directory as the base.

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

  // Enumerate Flutter-related roots and only consider those that contain
  // 'ios' or 'macos'. Compute the expected Mach-O path directly for each.
  await for (final String root
      in enumerateDebugSearchRoots(fs: fs, config: config)) {
    final String normalized = path.normalize(root);
    final String lower = normalized.toLowerCase();
    if (!(lower.contains('ios') || lower.contains('macos'))) {
      continue;
    }

    for (final String candidateBase in <String>{
      normalized,
      path.dirname(normalized),
    }) {
      final String machOPath = path.join(
        candidateBase,
        'App.framework.dSYM',
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

  return foundPaths;
}
