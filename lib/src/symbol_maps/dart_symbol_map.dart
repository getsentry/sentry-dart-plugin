import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';
import 'dart_symbol_map_debug_file_collector.dart';
import 'dart_symbol_map_discovery.dart';
import 'dart_symbol_map_uploader.dart';

/// Single, KISS-style entrypoint to upload Dart obfuscation map(s) paired with
/// Flutter-relevant native debug files.
///
/// - Resolves the Dart symbol map path from config
/// - Collects relevant debug files
/// - Uploads the map once per debug file via the CLI
Future<void> uploadDartSymbols({
  required FileSystem fs,
  required Configuration config,
}) async {
  final String? mapPath = await resolveDartMapPath(fs: fs, config: config);
  if (mapPath == null) {
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
    symbolMapPath: mapPath,
    debugFilePaths: debugFiles,
  );
}
