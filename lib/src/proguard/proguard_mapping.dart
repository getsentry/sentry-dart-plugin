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

  /// The Gradle variant it belongs to (`release`, `freeRelease`), i.e. the
  /// name of its directory, or null for an explicit `proguard_mapping_path`.
  final String? variant;

  ProguardMapping(this.path, this.builtAt, [this.variant]);
}

/// The outcome of [findProguardMapping].
class ProguardMappingLookup {
  /// The mapping to upload, or null. With several variants this is the most
  /// recent one, which is only a fallback: see [candidates].
  final ProguardMapping? mapping;

  /// Every discovered mapping, the most recent first. Empty for an explicit
  /// `proguard_mapping_path`. With several (e.g. flavors), the right one is
  /// the one of the variant whose APK/AAB carries the UUID.
  final List<ProguardMapping> candidates;

  /// Whether the reason for having no mapping was already logged.
  final bool reported;

  ProguardMappingLookup._(this.mapping,
      {this.candidates = const [], this.reported = false});
}

/// Finds the ProGuard/R8 mapping file to upload.
///
/// Uses [Configuration.proguardMappingPath] when set. Otherwise looks for
/// `<build_path>/app/outputs/mapping/<variant>/mapping.txt`, which is where
/// the Android Gradle Plugin writes it for minified Flutter builds. When
/// several variants have a mapping (e.g. flavors), [ProguardMappingLookup.mapping]
/// is the most recent one; the caller should prefer the mapping of the variant
/// that was built (R8 doesn't rewrite a mapping that is up to date, so the
/// newest one isn't necessarily the one just built).
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

  return ProguardMappingLookup._(candidates.first, candidates: candidates);
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
      mappings.add(ProguardMapping(
          file.path, await file.lastModified(), fs.path.basename(entity.path)));
    }
  }
  mappings.sort((a, b) => b.builtAt!.compareTo(a.builtAt!));
  return mappings;
}
