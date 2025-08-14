import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/utils/path_utils.dart';

void main() {
  group('resolveFilePath for dartSymbolMapPath', () {
    test('returns absolute path for absolute input', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/proj')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final absolutePath = '/proj/maps/obfuscation.json';
      fs.file(absolutePath).createSync(recursive: true);

      final config = Configuration()..dartSymbolMapPath = absolutePath;

      final result = await resolveFilePath(
        fs: fs,
        rawPath: config.dartSymbolMapPath,
        missingPathWarning:
            "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.",
        notFoundWarningBuilder: (raw) =>
            "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.",
      );
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

      final result = await resolveFilePath(
        fs: fs,
        rawPath: config.dartSymbolMapPath,
        missingPathWarning:
            "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.",
        notFoundWarningBuilder: (raw) =>
            "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.",
      );
      expect(result, equals(abs));
    });

    test('returns null and warns when path not provided', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/x')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final config = Configuration()..dartSymbolMapPath = null;

      final result = await resolveFilePath(
        fs: fs,
        rawPath: config.dartSymbolMapPath,
        missingPathWarning:
            "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.",
        notFoundWarningBuilder: (raw) =>
            "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.",
      );
      expect(result, isNull);
    });

    test('returns null and warns when file does not exist', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRoot = fs.directory('/p')..createSync(recursive: true);
      fs.currentDirectory = projectRoot;

      final config = Configuration()..dartSymbolMapPath = 'missing.map';

      final result = await resolveFilePath(
        fs: fs,
        rawPath: config.dartSymbolMapPath,
        missingPathWarning:
            "Skipping Dart symbol map uploads: no 'dart_symbol_map_path' provided.",
        notFoundWarningBuilder: (raw) =>
            "Skipping Dart symbol map uploads: Dart symbol map file not found at '${config.dartSymbolMapPath}'.",
      );
      expect(result, isNull);
    });
  });
}
