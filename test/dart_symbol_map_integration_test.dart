import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/utils/dart_symbol_map.dart';
import 'package:test/test.dart';

void main() {
  late FileSystem fs;
  late Configuration config;

  setUp(() {
    fs = MemoryFileSystem.test();
    config = Configuration();
    // Ensure predictable build folder default for tests, though scanning is disabled.
    config.buildFilesFolder = 'build';
    config.dartSymbolMapPath = null;
  });

  group('findDartSymbolMapPath (explicit path only, no scanning)', () {
    test('returns absolute path when explicit path is valid', () async {
      final file = fs.file('map.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('["A","B"]');

      config.dartSymbolMapPath = 'map.json';

      final result = await findDartSymbolMapPath(fs: fs, config: config);
      expect(result, equals(file.absolute.path));
    });

    test('throws when explicit path is missing', () async {
      config.dartSymbolMapPath = 'missing.json';
      expect(
        () => findDartSymbolMapPath(fs: fs, config: config),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when explicit path exists but is invalid', () async {
      final file = fs.file('invalid.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('[]'); // empty array is invalid
      config.dartSymbolMapPath = file.path;
      expect(
        () => findDartSymbolMapPath(fs: fs, config: config),
        throwsA(isA<Exception>()),
      );
    });

    test('returns null when explicit path is not provided', () async {
      // Place a valid map file somewhere under build to verify no scanning.
      fs.directory('build/assets').createSync(recursive: true);
      fs.file('build/assets/some_map')
        ..createSync()
        ..writeAsStringSync('["A","B"]');

      config.dartSymbolMapPath = null;
      final result = await findDartSymbolMapPath(fs: fs, config: config);
      expect(result, isNull);
    });
  });
}
