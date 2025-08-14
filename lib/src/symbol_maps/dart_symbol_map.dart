import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';
import '../utils/path.dart';
import 'dart_symbol_map_debug_files_collector.dart';
import 'dart_symbol_map_uploader.dart';

/// Single entrypoint to upload Dart obfuscation map(s) paired with
/// Flutter-relevant native debug files. This obfuscation map is used to
/// symbolicate Flutter issue titles for non-web platforms.
///
/// Steps:
/// - Resolves the Dart symbol map path from config
/// - Collects relevant debug files
/// - Uploads the map once per debug file via the CLI
Future<void> uploadDartSymbolMap({
  required FileSystem fs,
  required Configuration config,
}) async {
  final String? resolvedMapPath = await resolveFilePath(
    fs: fs,
    rawPath: config.dartSymbolMapPath,
    missingPathWarning:
        "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.",
    fileNotFoundWarning:
        "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.",
  );
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

  await DartSymbolMapUploader.addDebugIdMarkerAndUpload(
    config: config,
    symbolMapPath: resolvedMapPath,
    debugFilePaths: debugFiles,
  );
}
