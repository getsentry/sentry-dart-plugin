import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';

/// Resolves an absolute path to the Dart obfuscation map file if provided.
///
/// Behavior:
/// - When `config.dartSymbolMapPath` is null or empty, logs a warning and returns null.
/// - When the provided path does not exist, logs a warning and returns null.
/// - Otherwise, returns the absolute path to the map file.
Future<String?> resolveDartMapPath({
  required FileSystem fs,
  required Configuration config,
}) async {
  final String? providedPath = config.dartSymbolMapPath?.trim();
  if (providedPath == null || providedPath.isEmpty) {
    Log.warn(
        "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.");
    return null;
  }

  final File file = fs.file(providedPath);
  if (!await file.exists()) {
    Log.warn(
        "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.");
    return null;
  }

  return file.absolute.path;
}
