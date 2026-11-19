import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';

final _uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Whether [value] is a UUID that sentry-cli accepts for `--uuid`.
bool isValidProguardUuid(String value) => _uuidRegExp.hasMatch(value);

/// A ProGuard/R8 mapping file picked for upload.
class ProguardMapping {
  final String path;

  /// When the build wrote it, or null for an explicit `proguard_mapping_path`
  /// (which may have been copied there later).
  final DateTime? builtAt;

  ProguardMapping(this.path, this.builtAt);
}

/// The outcome of [findProguardMapping].
class ProguardMappingLookup {
  /// The mapping to upload, or null.
  final ProguardMapping? mapping;

  /// Whether the reason for having no mapping was already logged.
  final bool reported;

  ProguardMappingLookup._(this.mapping, {this.reported = false});
}

/// Finds the ProGuard/R8 mapping file to upload.
///
/// Uses [Configuration.proguardMappingPath] when set. Otherwise looks for
/// `<build_path>/app/outputs/mapping/<variant>/mapping.txt`, which is where
/// the Android Gradle Plugin writes it for minified Flutter builds. When
/// several variants have a mapping (e.g. flavors), the most recent one is
/// used, since it belongs to the build that just ran.
Future<ProguardMappingLookup> findProguardMapping({
  required FileSystem fs,
  required Configuration config,
}) async {
  final explicitPath = config.proguardMappingPath?.trim();
  if (explicitPath != null && explicitPath.isNotEmpty) {
    if (await fs.file(explicitPath).exists()) {
      return ProguardMappingLookup._(ProguardMapping(explicitPath, null));
    }
    Log.warn(
        "ProGuard mapping file not found at '$explicitPath' (proguard_mapping_path).");
    return ProguardMappingLookup._(null, reported: true);
  }

  final candidates = await listBuiltProguardMappings(fs: fs, config: config);
  if (candidates.isEmpty) {
    return ProguardMappingLookup._(null);
  }

  if (candidates.length > 1) {
    Log.warn(
      'Found multiple ProGuard mapping files: '
      '${candidates.map((m) => m.path).join(', ')}. '
      "Using the most recent one, '${candidates.first.path}'. "
      "Set 'proguard_mapping_path' to choose a specific one.",
    );
  }
  return ProguardMappingLookup._(candidates.first);
}

/// The `mapping.txt` files under `<build_path>/app/outputs/mapping/`, the
/// most recent first.
Future<List<ProguardMapping>> listBuiltProguardMappings({
  required FileSystem fs,
  required Configuration config,
}) async {
  final mappingDir = fs.directory(
    fs.path.join(config.buildFilesFolder, 'app', 'outputs', 'mapping'),
  );
  if (!await mappingDir.exists()) {
    return [];
  }

  final mappings = <ProguardMapping>[];
  await for (final entity in mappingDir.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final file = fs.file(fs.path.join(entity.path, 'mapping.txt'));
    if (await file.exists()) {
      mappings.add(ProguardMapping(file.path, await file.lastModified()));
    }
  }
  mappings.sort((a, b) => b.builtAt!.compareTo(a.builtAt!));
  return mappings;
}
