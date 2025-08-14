import 'package:file/file.dart';

import 'log.dart';

/// Resolves a provided file path to an absolute path if the file exists.
Future<String?> resolveFilePath({
  required FileSystem fs,
  required String? rawPath,
  required String missingPathWarning,
  required String fileNotFoundWarning,
}) async {
  final String? providedPath = rawPath?.trim();
  if (providedPath == null || providedPath.isEmpty) {
    Log.warn(missingPathWarning);
    return null;
  }

  final File file = fs.file(providedPath);
  if (!await file.exists()) {
    Log.warn(fileNotFoundWarning);
    return null;
  }

  return file.absolute.path;
}
