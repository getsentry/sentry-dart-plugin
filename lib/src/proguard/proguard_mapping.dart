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

/// The namespace for [proguardUuidFromMapId]: the one sentry-cli uses for
/// ProGuard UUIDs, uuid5(NAMESPACE_DNS, "guardsquare.com").
final _proguardNamespace = _uuid5(
  _uuidBytes('6ba7b810-9dad-11d1-80b4-00c04fd430c8'), // NAMESPACE_DNS
  'guardsquare.com',
);

/// The ProGuard UUID a mapping is uploaded under, derived from its R8 map ID:
/// uuid5(uuid5(NAMESPACE_DNS, "guardsquare.com"), mapId).
///
/// The SDK must derive the same UUID from the `pg-map-id` it reads at
/// runtime, so this must not change. [mapId] is used as written by R8
/// (lowercase hex, 7 or 64 characters).
String proguardUuidFromMapId(String mapId) =>
    _formatUuid(_uuid5(_proguardNamespace, mapId.toLowerCase()));

Uint8List _uuid5(Uint8List namespace, String name) {
  final hash = sha1.convert([...namespace, ...utf8.encode(name)]).bytes;
  final bytes = Uint8List.fromList(hash.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // version 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  return bytes;
}

Uint8List _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  return Uint8List.fromList([
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16)
  ]);
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
