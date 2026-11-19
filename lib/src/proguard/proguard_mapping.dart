import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';

final _uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Whether [value] is a UUID that sentry-cli accepts for `--uuid`.
bool isValidProguardUuid(String value) => _uuidRegExp.hasMatch(value);

/// Returns the ProGuard/R8 mapping file to upload, or null if there is none.
///
/// Uses [Configuration.proguardMappingPath] when set. Otherwise looks for
/// `<build_path>/app/outputs/mapping/<variant>/mapping.txt`, which is where
/// the Android Gradle Plugin writes it for minified Flutter builds. The
/// mapping is uploaded under a single forced UUID, so only one file can be
/// picked: when several variants have a mapping (e.g. flavors), the most
/// recently written one is used, since it belongs to the build that just ran.
Future<String?> findProguardMapping({
  required FileSystem fs,
  required Configuration config,
}) async {
  final explicitPath = config.proguardMappingPath?.trim();
  if (explicitPath != null && explicitPath.isNotEmpty) {
    if (await fs.file(explicitPath).exists()) {
      return explicitPath;
    }
    Log.warn(
        "ProGuard mapping file not found at '$explicitPath' (proguard_mapping_path).");
    return null;
  }

  final mappingDir = fs.directory(
    fs.path.join(config.buildFilesFolder, 'app', 'outputs', 'mapping'),
  );
  if (!await mappingDir.exists()) {
    return null;
  }

  final candidates = <File>[];
  await for (final entity in mappingDir.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final mapping = fs.file(fs.path.join(entity.path, 'mapping.txt'));
    if (await mapping.exists()) {
      candidates.add(mapping);
    }
  }

  if (candidates.isEmpty) {
    return null;
  }

  if (candidates.length > 1) {
    final modified = {
      for (final file in candidates) file: await file.lastModified(),
    };
    candidates.sort((a, b) => modified[b]!.compareTo(modified[a]!));
    Log.warn(
      'Found multiple ProGuard mapping files: '
      '${candidates.map((f) => f.path).join(', ')}. '
      "Using the most recent one, '${candidates.first.path}'. "
      "Set 'proguard_mapping_path' to choose a specific one.",
    );
  }

  return candidates.first.path;
}
