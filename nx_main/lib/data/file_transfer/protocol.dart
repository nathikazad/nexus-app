import 'dart:typed_data';

/// Transport-independent file transfer v2; matches firmware file_transfer.h.
enum FileKind { photo, audio, telemetry }

enum FileOp { begin, chunk, finish, resume, commit }

const fileHello = [0, 0x83, 2];
const maxFilePacket = 400;

int crc32Update(int crc, List<int> bytes) {
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >>> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
    }
  }
  return crc & 0xffffffff;
}

int crc32(List<int> bytes) => crc32Update(0xffffffff, bytes) ^ 0xffffffff;

class FileManifest {
  FileManifest(this.id, this.kind, this.name, this.size, this.checksum) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
        id == '0' * 32 ||
        !RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,62}$').hasMatch(name) ||
        name.contains('..') ||
        size < 0 ||
        size > 0xffffffff ||
        checksum < 0 ||
        checksum > 0xffffffff) {
      throw const FormatException('Invalid file manifest');
    }
  }
  final String id, name;
  final FileKind kind;
  final int size, checksum;
  String get contentType => switch (kind) {
        FileKind.photo => 'image/jpeg',
        FileKind.audio => 'application/vnd.nexus.opusraw',
        FileKind.telemetry => 'application/x-ndjson',
      };
  bool sameAs(FileManifest other) =>
      id == other.id &&
      kind == other.kind &&
      name == other.name &&
      size == other.size &&
      checksum == other.checksum;
  Uint8List begin() {
    final b = fileHeader(FileOp.begin, id, 10 + name.length);
    b[20] = kind.index + 1;
    final d = ByteData.sublistView(b);
    d.setUint32(21, size, Endian.little);
    d.setUint32(25, checksum, Endian.little);
    b[29] = name.length;
    b.setRange(30, b.length, name.codeUnits);
    return b;
  }

  Uint8List control(FileOp op, int offset) {
    if (offset < 0 || offset > size)
      throw const FormatException('Invalid offset');
    final b = fileHeader(op, id, 8), d = ByteData(8);
    d.setUint32(0, offset, Endian.little);
    d.setUint32(4, checksum, Endian.little);
    b.setRange(20, 28, d.buffer.asUint8List());
    return b;
  }
}

Uint8List fileHeader(FileOp op, String id, int bodyLength) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
      bodyLength + 20 > maxFilePacket) {
    throw const FormatException('Invalid packet');
  }
  final b = Uint8List(20 + bodyLength);
  b.setRange(0, 4, [0, 0x84, 2, op.index + 1]);
  for (var i = 0; i < 16; i++) {
    b[4 + i] = int.parse(id.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return b;
}

class FilePacket {
  FilePacket.parse(this.bytes) {
    if (bytes.length < 20 ||
        bytes.length > maxFilePacket ||
        bytes[0] != 0 ||
        bytes[1] != 0x84 ||
        bytes[2] != 2 ||
        bytes[3] < 1 ||
        bytes[3] > 5) throw const FormatException('Invalid file packet');
    op = FileOp.values[bytes[3] - 1];
    id = bytes
        .sublist(4, 20)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (id == '0' * 32) throw const FormatException('Invalid file ID');
  }
  final Uint8List bytes;
  late final FileOp op;
  late final String id;
  FileManifest manifest() {
    if (op != FileOp.begin ||
        bytes.length < 31 ||
        bytes[20] < 1 ||
        bytes[20] > 3 ||
        bytes.length != 30 + bytes[29])
      throw const FormatException('Invalid BEGIN');
    final d = ByteData.sublistView(bytes);
    return FileManifest(
        id,
        FileKind.values[bytes[20] - 1],
        String.fromCharCodes(bytes.sublist(30)),
        d.getUint32(21, Endian.little),
        d.getUint32(25, Endian.little));
  }

  int get offset {
    if (bytes.length < 24) throw const FormatException('Missing offset');
    return ByteData.sublistView(bytes).getUint32(20, Endian.little);
  }

  bool matches(FileManifest m, FileOp expected) =>
      op == expected &&
      id == m.id &&
      bytes.length == 28 &&
      offset <= m.size &&
      ByteData.sublistView(bytes).getUint32(24, Endian.little) == m.checksum;
}
