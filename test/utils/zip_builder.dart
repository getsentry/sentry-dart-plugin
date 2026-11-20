import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

/// Builds a minimal zip archive in memory, for tests that read APKs/AABs.
///
/// Entries listed in [deflated] are compressed with deflate, the others are
/// stored. CRC-32 is left at 0: the reader under test doesn't verify it.
Uint8List buildZip(
  Map<String, String> entries, {
  Set<String> deflated = const {},
  String comment = '',
}) {
  final out = BytesBuilder();
  final central = BytesBuilder();

  entries.forEach((name, content) {
    final nameBytes = utf8.encode(name);
    final raw = utf8.encode(content);
    final isDeflated = deflated.contains(name);
    final data = isDeflated ? ZLibEncoder(raw: true).convert(raw) : raw;
    final method = isDeflated ? 8 : 0;
    final offset = out.length;

    out
      ..add(_u32(0x04034b50))
      ..add(_u16(20)) // version needed
      ..add(_u16(0)) // flags
      ..add(_u16(method))
      ..add(_u32(0)) // time + date
      ..add(_u32(0)) // crc
      ..add(_u32(data.length))
      ..add(_u32(raw.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0)) // extra length
      ..add(nameBytes)
      ..add(data);

    central
      ..add(_u32(0x02014b50))
      ..add(_u16(20)) // version made by
      ..add(_u16(20)) // version needed
      ..add(_u16(0)) // flags
      ..add(_u16(method))
      ..add(_u32(0)) // time + date
      ..add(_u32(0)) // crc
      ..add(_u32(data.length))
      ..add(_u32(raw.length))
      ..add(_u16(nameBytes.length))
      ..add(_u16(0)) // extra length
      ..add(_u16(0)) // comment length
      ..add(_u16(0)) // disk number
      ..add(_u16(0)) // internal attributes
      ..add(_u32(0)) // external attributes
      ..add(_u32(offset))
      ..add(nameBytes);
  });

  final cdOffset = out.length;
  final cd = central.toBytes();
  final commentBytes = utf8.encode(comment);
  out
    ..add(cd)
    ..add(_u32(0x06054b50))
    ..add(_u16(0)) // disk number
    ..add(_u16(0)) // disk with central directory
    ..add(_u16(entries.length))
    ..add(_u16(entries.length))
    ..add(_u32(cd.length))
    ..add(_u32(cdOffset))
    ..add(_u16(commentBytes.length))
    ..add(commentBytes);
  return out.toBytes();
}

Uint8List _u16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
