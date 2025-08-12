import 'dart:convert';

import 'package:file/file.dart';

import '../configuration.dart';
import 'flutter_debug_files.dart';

/// Validates whether a file looks like a Dart obfuscation map.
///
/// Expected minimal shape: top-level JSON array of strings with an even length
/// (pairs of original and obfuscated names).
Future<bool> isValidDartSymbolMapFile(File file) async {
  try {
    // Basic size guard: reject extremely large files to avoid excessive memory usage.
    final stat = await file.stat();
    // ~20MB upper bound is generous for typical obfuscation maps.
    const int maxBytes = 20 * 1024 * 1024;
    if (stat.size > maxBytes) return false;

    final content = (await file.readAsString()).trim();
    if (!(content.startsWith('[') && content.endsWith(']'))) return false;

    final decoded = jsonDecode(content);
    if (decoded is! List) return false;
    if (decoded.isEmpty || decoded.length.isOdd) return false;
    for (final item in decoded) {
      if (item is! String) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// If [configuredPath] is provided, validates and returns the absolute path to the Dart symbol map.
/// If not provided, returns null.
///
/// Note: we do not scan the filesystem for this file because the file does not
/// have a special extension so worst case we would have to check every file.
Future<String?> resolveDartSymbolMapPath({
  required FileSystem fs,
  String? configuredPath,
}) async {
  if (configuredPath == null || configuredPath.isEmpty) return null;

  final file = fs.file(configuredPath);
  if (!await file.exists()) {
    throw StateError(
      "Dart symbol map file not found at '$configuredPath'. Ensure the path is correct and the file exists.",
    );
  }

  if (!await isValidDartSymbolMapFile(file)) {
    throw StateError(
      "Invalid Dart symbol map at '$configuredPath'. It must be a JSON array of strings with an even number of elements.",
    );
  }

  return file.absolute.path;
}

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

    final file = fs.file(rootPath);
    if (await file.exists()) {
      final String basename = fs.path.basename(file.path);
      if (basename.startsWith('app') &&
          basename.endsWith('.symbols') &&
          !basename.contains('darwin')) {
        foundPaths.add(file.absolute.path);
      }
    }
  }

  // First, scan the configured symbols folder (if any)
  if (config.symbolsFolder.isNotEmpty) {
    await collectAndroidSymbolsUnder(config.symbolsFolder);
  }

  // Backward compatibility: also scan build folder if different
  if (config.buildFilesFolder != config.symbolsFolder) {
    await collectAndroidSymbolsUnder(config.buildFilesFolder);
  }

  // Then, scan all current search roots used by the plugin
  await for (final root in enumerateDebugSearchRoots(fs: fs, config: config)) {
    await collectAndroidSymbolsUnder(root);
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

  // Search under the build directory directly to catch common iOS layouts
  await collectAppleMachOUnder(config.buildFilesFolder);

  // Search all known roots (includes Fastlane ios/build)
  await for (final root in enumerateDebugSearchRoots(fs: fs, config: config)) {
    await collectAppleMachOUnder(root);
  }

  return foundPaths;
}
