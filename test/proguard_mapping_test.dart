import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_mapping.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

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

  group('findProguardMapping', () {
    test('returns null when there is no mapping directory', () async {
      expect((await findProguardMapping(fs: fs, config: config)).mapping?.path,
          isNull);
    });

    test('returns null when no variant has a mapping.txt', () async {
      fs
          .directory('build/app/outputs/mapping/release')
          .createSync(recursive: true);
      expect((await findProguardMapping(fs: fs, config: config)).mapping?.path,
          isNull);
    });

    test('finds the mapping of the single variant', () async {
      createMapping('release');
      expect(
        (await findProguardMapping(fs: fs, config: config)).mapping?.path,
        'build/app/outputs/mapping/release/mapping.txt',
      );
    });

    test('respects a custom build_path', () async {
      config.buildFilesFolder = 'out';
      fs
          .file('out/app/outputs/mapping/release/mapping.txt')
          .createSync(recursive: true);
      expect(
        (await findProguardMapping(fs: fs, config: config)).mapping?.path,
        'out/app/outputs/mapping/release/mapping.txt',
      );
    });

    test('picks the most recent mapping when several variants have one',
        () async {
      createMapping('freeRelease', modified: DateTime(2026, 1, 1));
      createMapping('paidRelease', modified: DateTime(2026, 1, 2));
      createMapping('release', modified: DateTime(2025, 12, 31));
      expect(
        (await findProguardMapping(fs: fs, config: config)).mapping?.path,
        'build/app/outputs/mapping/paidRelease/mapping.txt',
      );
    });

    test('lists every variant mapping, the most recent first', () async {
      createMapping('freeRelease', modified: DateTime(2026, 1, 1));
      createMapping('paidRelease', modified: DateTime(2026, 1, 2));
      final lookup = await findProguardMapping(fs: fs, config: config);
      expect(lookup.candidates.map((m) => m.variant),
          ['paidRelease', 'freeRelease']);
    });

    test('uses proguard_mapping_path over discovered mappings', () async {
      createMapping('release');
      fs.file('custom/mapping.txt').createSync(recursive: true);
      config.proguardMappingPath = 'custom/mapping.txt';
      expect(
        (await findProguardMapping(fs: fs, config: config)).mapping?.path,
        'custom/mapping.txt',
      );
    });

    test('returns null when proguard_mapping_path does not exist', () async {
      createMapping('release');
      config.proguardMappingPath = 'missing/mapping.txt';
      expect((await findProguardMapping(fs: fs, config: config)).mapping?.path,
          isNull);
    });

    test('ignores a blank proguard_mapping_path', () async {
      createMapping('release');
      config.proguardMappingPath = '  ';
      expect(
        (await findProguardMapping(fs: fs, config: config)).mapping?.path,
        'build/app/outputs/mapping/release/mapping.txt',
      );
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
