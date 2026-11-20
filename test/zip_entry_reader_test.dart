import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/utils/zip_entry_reader.dart';
import 'package:test/test.dart';

import 'utils/zip_builder.dart';

void main() {
  late FileSystem fs;

  setUp(() => fs = MemoryFileSystem.test());

  File zipWith(Map<String, String> entries,
          {Set<String> deflated = const {}, String comment = ''}) =>
      fs.file('app.apk')
        ..writeAsBytesSync(
            buildZip(entries, deflated: deflated, comment: comment));

  Future<String?> read(File file, String name, {int? maxSize}) async {
    final bytes = maxSize == null
        ? await readZipEntry(file, name)
        : await readZipEntry(file, name, maxSize: maxSize);
    return bytes == null ? null : utf8.decode(bytes);
  }

  test('reads a stored entry', () async {
    final file = zipWith({'a.txt': 'first', 'assets/b.txt': 'second'});
    expect(await read(file, 'assets/b.txt'), 'second');
    expect(await read(file, 'a.txt'), 'first');
  });

  test('reads a deflated entry', () async {
    final file = zipWith(
      {'assets/b.txt': 'deflated content ' * 20},
      deflated: {'assets/b.txt'},
    );
    expect(await read(file, 'assets/b.txt'), 'deflated content ' * 20);
  });

  test('finds the index behind an archive comment', () async {
    final file = zipWith({'a.txt': 'x'}, comment: 'some trailing comment');
    expect(await read(file, 'a.txt'), 'x');
  });

  test('returns null for a missing entry', () async {
    final file = zipWith({'a.txt': 'x'});
    expect(await read(file, 'assets/a.txt'), isNull);
  });

  test('returns null for entries above maxSize', () async {
    final file = zipWith({'a.txt': 'x' * 100});
    expect(await read(file, 'a.txt', maxSize: 10), isNull);
    expect(await read(file, 'a.txt', maxSize: 100), 'x' * 100);
  });

  test('returns null for files that are not zip archives', () async {
    expect(
        await read(fs.file('empty')..writeAsStringSync(''), 'a.txt'), isNull);
    expect(
      await read(fs.file('text')..writeAsStringSync('not a zip ' * 10), 'a'),
      isNull,
    );
  });
}
