import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';
import 'dart_symbol_map_discovery.dart';
import 'dart_symbol_map_uploader.dart';

/// Single entrypoint to upload Dart obfuscation map(s) paired with
/// Flutter-relevant native debug files.
///
/// - Resolves the Dart symbol map path from config
/// - Collects relevant debug files
/// - Uploads the map once per debug file via the CLI
Future<void> uploadDartSymbolMaps({
  required FileSystem fs,
  required Configuration config,
}) async {
  // Validate the configured map path, but pass the original string to the CLI
  // to match user-provided (potentially relative) paths expected by tests.
  final String? resolvedMapPath =
      await resolveDartMapPath(fs: fs, config: config);
  if (resolvedMapPath == null) {
    return;
  }

  final Set<String> debugFiles =
      await collectDebugFilesForDartMap(fs: fs, config: config);

  if (debugFiles.isEmpty) {
    Log.warn(
        'Skipping Dart symbol map uploads: no Flutter-relevant debug files found.');
    return;
  }

  await DartSymbolMapUploader.upload(
    config: config,
    symbolMapPath: (config.dartSymbolMapPath ?? '').trim(),
    debugFilePaths: debugFiles,
  );
}
