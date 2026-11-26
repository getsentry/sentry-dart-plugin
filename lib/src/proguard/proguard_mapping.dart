import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';

import '../configuration.dart';
import '../utils/log.dart';

final _uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Whether [value] is a UUID that sentry-cli accepts for `--uuid`.
bool isValidProguardUuid(String value) => _uuidRegExp.hasMatch(value);

/// The `# pg_map_id: <id>` line R8 writes at the top of every mapping file.
/// The same ID is in the app's `~~R8{"backend":"dex",...,"pg-map-id":...}`
/// marker in `classes.dex`, which is where the SDK reads it at runtime.
/// Newer R8 writes 64 hex characters, R8 before AGP 8.12 writes 7.
final _mapIdRegExp = RegExp(r'^# pg_map_id: ([0-9a-fA-F]+)\s*$');

/// R8 writes its header comments first; the map ID is within the first few
/// lines. Stop reading there instead of scanning a mapping of many megabytes.
const _headerLinesToScan = 20;

/// Returns the R8 map ID from the header of the mapping at [path], or null if
/// it has none (e.g. a ProGuard or DexGuard mapping).
Future<String?> readProguardMapId(FileSystem fs, String path) async {
  var lineCount = 0;
  await for (final line in fs
      .file(path)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    final match = _mapIdRegExp.firstMatch(line);
    if (match != null) {
      return match.group(1)!.toLowerCase();
    }
    if (++lineCount >= _headerLinesToScan || !line.startsWith('#')) {
      break;
    }
  }
  return null;
}

/// The ProGuard UUID a mapping is uploaded under, derived from its R8 map ID
/// the way Java's `UUID.nameUUIDFromBytes(mapId.getBytes())` does (UUIDv3:
/// MD5 of the ID, no namespace).
///
/// This matches the Sentry Android Gradle Plugin, which uploads under
/// `UUID.nameUUIDFromBytes(pg_map_hash)`. With current R8 the map ID is that
/// same 64 character hash, so both tools agree on the UUID for a mapping.
///
/// The SDK must derive the same UUID from the `pg-map-id` it reads at
/// runtime, so this must not change. [mapId] is used as written by R8
/// (lowercase hex, 7 or 64 characters).
String proguardUuidFromMapId(String mapId) =>
    _formatUuid(_uuid3(mapId.toLowerCase()));

Uint8List _uuid3(String name) {
  final bytes = Uint8List.fromList(md5.convert(utf8.encode(name)).bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x30; // version 3
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  return bytes;
}

String _formatUuid(Uint8List bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Returns the ProGuard/R8 mapping files to upload, the most recent first.
///
/// Uses [Configuration.proguardMappingPath] when set. Otherwise returns every
/// `<build_path>/app/outputs/mapping/<variant>/mapping.txt`, which is where
/// the Android Gradle Plugin writes it for minified Flutter builds. Each one is
/// uploaded under the UUID of its own R8 map ID, so mappings of other variants
/// or older builds never match the wrong app.
Future<List<String>> findProguardMappings({
  required FileSystem fs,
  required Configuration config,
}) async {
  final explicitPath = config.proguardMappingPath?.trim();
  if (explicitPath != null && explicitPath.isNotEmpty) {
    if (await fs.file(explicitPath).exists()) {
      return [explicitPath];
    }
    Log.warn(
        "ProGuard mapping file not found at '$explicitPath' (proguard_mapping_path).");
    return [];
  }

  final mappingDir = fs.directory(
    fs.path.join(config.buildFilesFolder, 'app', 'outputs', 'mapping'),
  );
  if (!await mappingDir.exists()) {
    return [];
  }

  final modified = <String, DateTime>{};
  await for (final entity in mappingDir.list(followLinks: false)) {
    if (entity is! Directory) {
      continue;
    }
    final mapping = fs.file(fs.path.join(entity.path, 'mapping.txt'));
    if (await mapping.exists()) {
      modified[mapping.path] = await mapping.lastModified();
    }
  }
  return modified.keys.toList()
    ..sort((a, b) => modified[b]!.compareTo(modified[a]!));
}
