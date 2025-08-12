import 'package:file/file.dart';

import '../configuration.dart';
import 'flutter_debug_files.dart';

/// Finds Flutter-relevant debug file paths for Android and Apple (iOS/macOS)
/// that should be paired with a Dart symbol map.
Future<Set<String>> findFlutterRelevantDebugFilePaths({
  required FileSystem fs,
  required Configuration config,
}) async {
  final Set<String> foundPaths = <String>{};

  Future<void> collectAndroidSymbolsUnder(String rootPath) async {
    if (rootPath.isEmpty) return;

    final directory = fs.directory(rootPath);
    if (await directory.exists()) {
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final String basename = fs.path.basename(entity.path);
        if (basename.startsWith('app') &&
            basename.endsWith('.symbols') &&
            !basename.contains('darwin')) {
          foundPaths.add(fs.file(entity.path).absolute.path);
        }
      }
      return;
    }
  }

  if (config.symbolsFolder.isNotEmpty) {
    await collectAndroidSymbolsUnder(config.symbolsFolder);
  }

  if (config.buildFilesFolder != config.symbolsFolder) {
    await collectAndroidSymbolsUnder(config.buildFilesFolder);
  }

  Future<void> collectAppleMachOUnder(String rootPath) async {
    if (rootPath.isEmpty) return;
    final dir = fs.directory(rootPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
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

  await collectAppleMachOUnder(config.buildFilesFolder);

  await for (final root in enumerateDebugSearchRoots(fs: fs, config: config)) {
    await collectAppleMachOUnder(root);
    await collectAndroidSymbolsUnder(root);
  }

  return foundPaths;
}
