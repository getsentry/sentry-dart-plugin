import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_mapping.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

/// Header of a mapping written by R8 9.1 (full map ID).
const r8Header = '''
# compiler: R8
# compiler_version: 9.1.31
# min_api: 24
# common_typos_disable
# {"id":"com.android.tools.r8.mapping","version":"2.2"}
# pg_map_id: f9245ea8f32c0d479b2e12eac7d01f87792e3464ee8d263e8a365d7651196605
com.example.Foo -> a.a:
''';

void main() {
  late FileSystem fs;
  late Configuration config;

  setUp(() {
    fs = MemoryFileSystem.test();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    config = Configuration()
      ..buildFilesFolder = 'build'
      ..proguardMappingPath = null;
  });

  File createMapping(String variant, {DateTime? modified}) {
    final file = fs.file('build/app/outputs/mapping/$variant/mapping.txt')
      ..createSync(recursive: true);
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
    return file;
  }

  group('findProguardMappings', () {
    test('returns nothing when there is no mapping directory', () async {
      expect(await findProguardMappings(fs: fs, config: config), isEmpty);
    });

    test('returns nothing when no variant has a mapping.txt', () async {
      fs
          .directory('build/app/outputs/mapping/release')
          .createSync(recursive: true);
      expect(await findProguardMappings(fs: fs, config: config), isEmpty);
    });

    test('finds the mapping of the single variant', () async {
      createMapping('release');
      expect(
        await findProguardMappings(fs: fs, config: config),
        ['build/app/outputs/mapping/release/mapping.txt'],
      );
    });

    test('respects a custom build_path', () async {
      config.buildFilesFolder = 'out';
      fs
          .file('out/app/outputs/mapping/release/mapping.txt')
          .createSync(recursive: true);
      expect(
        await findProguardMappings(fs: fs, config: config),
        ['out/app/outputs/mapping/release/mapping.txt'],
      );
    });

    test('returns every variant, the most recent first', () async {
      createMapping('freeRelease', modified: DateTime(2026, 1, 1));
      createMapping('paidRelease', modified: DateTime(2026, 1, 2));
      createMapping('release', modified: DateTime(2025, 12, 31));
      expect(await findProguardMappings(fs: fs, config: config), [
        'build/app/outputs/mapping/paidRelease/mapping.txt',
        'build/app/outputs/mapping/freeRelease/mapping.txt',
        'build/app/outputs/mapping/release/mapping.txt',
      ]);
    });

    test('uses only proguard_mapping_path when set', () async {
      createMapping('release');
      fs.file('custom/mapping.txt').createSync(recursive: true);
      config.proguardMappingPath = 'custom/mapping.txt';
      expect(
        await findProguardMappings(fs: fs, config: config),
        ['custom/mapping.txt'],
      );
    });

    test('returns nothing when proguard_mapping_path does not exist', () async {
      createMapping('release');
      config.proguardMappingPath = 'missing/mapping.txt';
      expect(await findProguardMappings(fs: fs, config: config), isEmpty);
    });

    test('ignores a blank proguard_mapping_path', () async {
      createMapping('release');
      config.proguardMappingPath = '  ';
      expect(
        await findProguardMappings(fs: fs, config: config),
        ['build/app/outputs/mapping/release/mapping.txt'],
      );
    });
  });

  group('readProguardMapId', () {
    Future<String?> read(String content) async {
      fs.file('mapping.txt').writeAsStringSync(content);
      return readProguardMapId(fs, 'mapping.txt');
    }

    test('reads the full map ID of newer R8', () async {
      expect(
        await read(r8Header),
        'f9245ea8f32c0d479b2e12eac7d01f87792e3464ee8d263e8a365d7651196605',
      );
    });

    test('reads the 7 character map ID of older R8, not pg_map_hash', () async {
      // Written by R8 8.6.17 (AGP 8.6.0). The DEX marker has the same 7 chars.
      expect(await read('''
# compiler: R8
# compiler_version: 8.6.17
# min_api: 24
# common_typos_disable
# {"id":"com.android.tools.r8.mapping","version":"2.2"}
# pg_map_id: 1bab4a8
# pg_map_hash: SHA-256 1bab4a8cdcebada781486a41042bc2b9b6ad9960c51eaf668ca5d39456b5923d
_COROUTINE.ArtificialStackFrames -> R8\$\$REMOVED\$\$CLASS\$\$0:
'''), '1bab4a8');
    });

    test('lowercases the map ID', () async {
      expect(await read('# compiler: R8\n# pg_map_id: 1BAB4A8\n'), '1bab4a8');
    });

    test('returns null for a mapping without a map ID', () async {
      // ProGuard and DexGuard mappings have no R8 header.
      expect(
          await read('com.example.Foo -> a.a:\n    void bar() -> a\n'), isNull);
    });

    test('ignores a map ID line after the header', () async {
      expect(
        await read('# compiler: R8\ncom.example.Foo -> a.a:\n'
            '# pg_map_id: 1bab4a8\n'),
        isNull,
      );
    });

    test('returns null for an empty file', () async {
      expect(await read(''), isNull);
    });
  });

  group('proguardUuidFromMapId', () {
    // Reference values match Java's UUID.nameUUIDFromBytes(mapId.getBytes()),
    // which the Sentry Android Gradle Plugin uses. From Python:
    // uuid.UUID(bytes=hashlib.md5(map_id.encode()).digest(), version=3)
    test('derives a stable UUIDv3 from a full map ID', () {
      expect(
        proguardUuidFromMapId(
            'f9245ea8f32c0d479b2e12eac7d01f87792e3464ee8d263e8a365d7651196605'),
        '072e7281-9c81-34d3-8619-c4ae24deb47b',
      );
    });

    test('derives a stable UUIDv3 from a short map ID', () {
      expect(proguardUuidFromMapId('1bab4a8'),
          '6b578c6e-74aa-3dc4-88ce-0d13d6802d5b');
    });

    test('is case-insensitive', () {
      expect(
          proguardUuidFromMapId('1BAB4A8'), proguardUuidFromMapId('1bab4a8'));
    });

    test('produces a UUID sentry-cli accepts', () {
      expect(isValidProguardUuid(proguardUuidFromMapId('1bab4a8')), isTrue);
    });
  });

  group('isValidProguardUuid', () {
    test('accepts lower and upper case UUIDs', () {
      expect(
          isValidProguardUuid('c9fb2840-1f9c-4f08-81fe-6880753f345b'), isTrue);
      expect(
          isValidProguardUuid('C9FB2840-1F9C-4F08-81FE-6880753F345B'), isTrue);
    });

    test('rejects malformed values', () {
      expect(isValidProguardUuid(''), isFalse);
      expect(isValidProguardUuid('not-a-uuid'), isFalse);
      expect(isValidProguardUuid('c9fb28401f9c4f0881fe6880753f345b'), isFalse);
      expect(isValidProguardUuid(' c9fb2840-1f9c-4f08-81fe-6880753f345b'),
          isFalse);
    });
  });
}
