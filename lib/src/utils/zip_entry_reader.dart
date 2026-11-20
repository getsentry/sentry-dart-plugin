import 'dart:io' show ZLibDecoder;
import 'dart:math';
import 'dart:typed_data';

import 'package:file/file.dart';

const _endOfCentralDirSignature = 0x06054b50;
const _centralDirEntrySignature = 0x02014b50;
const _localHeaderSignature = 0x04034b50;
const _endOfCentralDirMinSize = 22;
// The EOCD record ends with a comment of at most 0xFFFF bytes.
const _endOfCentralDirMaxSize = _endOfCentralDirMinSize + 0xFFFF;

/// Reads a single entry from the zip archive [zipFile] (e.g. an APK or AAB),
/// without loading the whole archive into memory.
///
/// Only the central directory and the requested entry are read. Returns null
/// when the archive has no entry named [entryName], when the entry is larger
/// than [maxSize] bytes, or when the archive uses features this reader does
/// not support (ZIP64, encryption, compression other than stored/deflate).
Future<Uint8List?> readZipEntry(
  File zipFile,
  String entryName, {
  int maxSize = 1024 * 1024,
}) async {
  final raf = await zipFile.open();
  try {
    final length = await raf.length();
    if (length < _endOfCentralDirMinSize) {
      return null;
    }

    final tailSize = min(length, _endOfCentralDirMaxSize);
    final tail = await _readAt(raf, length - tailSize, tailSize);
    final eocd = _findEndOfCentralDir(tail);
    if (eocd == null) {
      return null;
    }

    final cdSize = eocd.getUint32(12, Endian.little);
    final cdOffset = eocd.getUint32(16, Endian.little);
    if (cdSize == 0xFFFFFFFF || cdOffset == 0xFFFFFFFF) {
      return null; // ZIP64
    }
    if (cdOffset + cdSize > length) {
      return null;
    }

    final cd = ByteData.sublistView(await _readAt(raf, cdOffset, cdSize));
    var pos = 0;
    while (pos + 46 <= cd.lengthInBytes) {
      if (cd.getUint32(pos, Endian.little) != _centralDirEntrySignature) {
        return null;
      }
      final flags = cd.getUint16(pos + 8, Endian.little);
      final method = cd.getUint16(pos + 10, Endian.little);
      final compressedSize = cd.getUint32(pos + 20, Endian.little);
      final uncompressedSize = cd.getUint32(pos + 24, Endian.little);
      final nameLength = cd.getUint16(pos + 28, Endian.little);
      final extraLength = cd.getUint16(pos + 30, Endian.little);
      final commentLength = cd.getUint16(pos + 32, Endian.little);
      final localHeaderOffset = cd.getUint32(pos + 42, Endian.little);
      final nameStart = pos + 46;
      if (nameStart + nameLength > cd.lengthInBytes) {
        return null;
      }
      final name = String.fromCharCodes(
          Uint8List.sublistView(cd, nameStart, nameStart + nameLength));

      if (name == entryName) {
        if (flags & 0x1 != 0) {
          return null; // encrypted
        }
        if (compressedSize > maxSize || uncompressedSize > maxSize) {
          return null;
        }
        return await _readEntryData(
          raf,
          localHeaderOffset: localHeaderOffset,
          compressedSize: compressedSize,
          method: method,
          maxSize: maxSize,
        );
      }

      pos = nameStart + nameLength + extraLength + commentLength;
    }
    return null;
  } finally {
    await raf.close();
  }
}

ByteData? _findEndOfCentralDir(Uint8List tail) {
  final data = ByteData.sublistView(tail);
  for (var i = tail.length - _endOfCentralDirMinSize; i >= 0; i--) {
    if (data.getUint32(i, Endian.little) == _endOfCentralDirSignature) {
      return ByteData.sublistView(tail, i);
    }
  }
  return null;
}

Future<Uint8List?> _readEntryData(
  RandomAccessFile raf, {
  required int localHeaderOffset,
  required int compressedSize,
  required int method,
  required int maxSize,
}) async {
  final header =
      ByteData.sublistView(await _readAt(raf, localHeaderOffset, 30));
  if (header.lengthInBytes < 30 ||
      header.getUint32(0, Endian.little) != _localHeaderSignature) {
    return null;
  }
  // The local header's name and extra field lengths may differ from the
  // central directory's, so the data offset has to be taken from here.
  final nameLength = header.getUint16(26, Endian.little);
  final extraLength = header.getUint16(28, Endian.little);
  final dataOffset = localHeaderOffset + 30 + nameLength + extraLength;
  final compressed = await _readAt(raf, dataOffset, compressedSize);
  if (compressed.length != compressedSize) {
    return null;
  }

  switch (method) {
    case 0: // stored
      return compressed;
    case 8: // deflate
      try {
        final inflated = ZLibDecoder(raw: true).convert(compressed);
        return inflated.length > maxSize ? null : Uint8List.fromList(inflated);
      } on FormatException {
        return null;
      }
    default:
      return null;
  }
}

Future<Uint8List> _readAt(RandomAccessFile raf, int offset, int count) async {
  await raf.setPosition(offset);
  return raf.read(count);
}
