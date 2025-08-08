import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/utils/dart_symbol_map.dart';
import 'package:test/test.dart';

void main() {
  late FileSystem fs;

  setUp(() {
    fs = MemoryFileSystem.test();
  });

  group('isValidDartSymbolMapFile', () {
    test('valid when array of strings with even length (single pair)',
        () async {
      final file = fs.file('map.json')..writeAsStringSync('["A","B"]');
      expect(await isValidDartSymbolMapFile(file), isTrue);
    });

    test('valid when array has multiple pairs', () async {
      final file = fs.file('map_multi.json')
        ..writeAsStringSync('["MaterialApp","ex","Scaffold","ey"]');
      expect(await isValidDartSymbolMapFile(file), isTrue);
    });

    test('valid when trailing whitespace/newline present', () async {
      final file = fs.file('map_ws.json')..writeAsStringSync('["A","B"]\n  ');
      expect(await isValidDartSymbolMapFile(file), isTrue);
    });

    test('invalid when empty array', () async {
      final file = fs.file('empty.json')..writeAsStringSync('[]');
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });

    test('invalid when odd number of elements', () async {
      final file = fs.file('odd.json')..writeAsStringSync('["A"]');
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });

    test('invalid when non-string element present', () async {
      final file = fs.file('non_string.json')..writeAsStringSync('[1, "A"]');
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });

    test('invalid when top-level JSON is not an array', () async {
      final file = fs.file('not_array.json')..writeAsStringSync('{"a":"b"}');
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });

    test('invalid when malformed JSON', () async {
      final file = fs.file('malformed.json')..writeAsStringSync('[');
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });

    test('invalid when file larger than maximum threshold', () async {
      final file = fs.file('too_big');
      // Create a file of size kMaxDartSymbolMapSizeBytes + 1 without valid JSON
      // to trigger size-based rejection without decoding.
      final tooBig = kMaxDartSymbolMapSizeBytes + 1;
      await file.writeAsBytes(Uint8List(tooBig));
      expect(await isValidDartSymbolMapFile(file), isFalse);
    });
  });
}
