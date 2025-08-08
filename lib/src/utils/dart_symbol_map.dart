import 'dart:convert';

import 'package:file/file.dart';

import '../configuration.dart';

/// Maximum Dart symbol map file size to consider during validation (20 MiB).
const int kMaxDartSymbolMapSizeBytes = 20 * 1024 * 1024;

/// Validates whether the given [file] contains a Dart obfuscation map.
///
/// A valid map is a JSON array of strings with even length and at least one
/// pair (length >= 2), e.g. ["MaterialApp", "ex", "Scaffold", "ey"].
Future<bool> isValidDartSymbolMapFile(File file) async {
  try {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return false;
    if (stat.size <= 0 || stat.size > kMaxDartSymbolMapSizeBytes) return false;

    final content = await file.readAsString();
    final trimmed = content.trim();
    if (trimmed.length < 2) return false;
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return false;

    final dynamic decoded = jsonDecode(trimmed);
    if (decoded is! List) return false;
    if (decoded.isEmpty) return false;
    if (decoded.length.isOdd) return false;
    if (decoded.length < 2) return false;
    for (final element in decoded) {
      if (element is! String) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Attempts to resolve the Dart obfuscation map path.
///
/// - If [config.dartSymbolMapPath] is provided, it must exist and be valid,
///   otherwise an [Exception] is thrown. On success, returns the absolute path.
/// - Otherwise, returns null (no scanning by default due to performance).
Future<String?> findDartSymbolMapPath({
  required FileSystem fs,
  required Configuration config,
}) async {
  final String? explicitPath = config.dartSymbolMapPath;
  if (explicitPath != null && explicitPath.isNotEmpty) {
    final file = fs.file(explicitPath);
    if (!await file.exists()) {
      throw Exception(
        "Dart symbol map not found at provided path '$explicitPath'.",
      );
    }
    final isValid = await isValidDartSymbolMapFile(file);
    if (!isValid) {
      throw Exception(
        "Provided 'dart_symbol_map_path' is not a valid Dart obfuscation map: '$explicitPath'.",
      );
    }
    return file.absolute.path;
  }
  return null;
}
