import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/symbol_maps/dart_symbol_map_discovery.dart';

void main() {
  group('resolveDartMapPath', () {
    test('returns absolute path for absolute input', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/proj')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final absolutePath = '/proj/maps/obfuscation.json';
      fs.file(absolutePath).createSync(recursive: true);

      final config = Configuration()..dartSymbolMapPath = absolutePath;

      final result = await resolveDartMapPath(fs: fs, config: config);
      expect(result, equals(absolutePath));
    });

    test('resolves relative path to absolute when file exists', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/root')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final rel = 'build/app/obfuscation.map';
      final abs = '/root/build/app/obfuscation.map';
      fs.file(abs).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = '/root/build'
        ..symbolsFolder = '/root/symbols'
        ..dartSymbolMapPath = rel;

      final result = await resolveDartMapPath(fs: fs, config: config);
      expect(result, equals(abs));
    });

    test('returns null and warns when path not provided', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/x')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final config = Configuration()..dartSymbolMapPath = null;

      final result = await resolveDartMapPath(fs: fs, config: config);
      expect(result, isNull);
    });

    test('returns null and warns when file does not exist', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/p')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final config = Configuration()..dartSymbolMapPath = 'missing.map';

      final result = await resolveDartMapPath(fs: fs, config: config);
      expect(result, isNull);
    });
  });
}
