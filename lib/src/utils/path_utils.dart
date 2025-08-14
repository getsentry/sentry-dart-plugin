import 'package:file/file.dart';

import 'log.dart';

/// Resolves a config-provided file path to an absolute path if the file exists.
///
/// - If [rawPath] is null or empty (after trimming), logs [missingWarning]
///   and returns null.
/// - If the file at the trimmed path does not exist, logs the message returned
///   by [notFoundWarningBuilder] (called with the untrimmed [rawPath]) and
///   returns null.
/// - Otherwise returns the absolute path of the file.
Future<String?> resolveFilePath({
  required FileSystem fs,
  required String? rawPath,
  required String missingWarning,
  required String Function(String rawPath) notFoundWarningBuilder,
}) async {
  final String? providedPath = rawPath?.trim();
  if (providedPath == null || providedPath.isEmpty) {
    Log.warn(missingWarning);
    return null;
  }

  final File file = fs.file(providedPath);
  if (!await file.exists()) {
    Log.warn(notFoundWarningBuilder(rawPath ?? ''));
    return null;
  }

  return file.absolute.path;
}
