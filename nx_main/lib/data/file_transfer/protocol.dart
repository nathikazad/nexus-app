import 'dart:typed_data';

/// File transfer v3: OPEN has identity only; CLOSE supplies final size/checksum.
enum FileKind { photo, audio, telemetry }

enum FileOp { open, data, close, status }

const fileHello = [0, 0x83, 3];
const maxFilePacket = 400;
const fileDataHeader = 10;

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

bool _validId(String id) =>
    RegExp(r'^[0-9a-f]{32}$').hasMatch(id) && id != '0' * 32;
void _uint32(int value) {
  if (value < 0 || value > 0xffffffff)
    throw const FormatException('Invalid uint32');
}

void _handle(int value) {
  if (value < 1 || value > 0xffff)
    throw const FormatException('Invalid handle');
}

Uint8List _frame(FileOp op, int length) {
  if (length < 4 || length > maxFilePacket)
    throw const FormatException('Invalid frame length');
  final b = Uint8List(length);
  b.setRange(0, 4, [0, 0x84, 3, op.index + 1]);
  return b;
}

void _id(Uint8List bytes, String id) {
  if (!_validId(id)) throw const FormatException('Invalid file ID');
  for (var i = 0; i < 16; i++) {
    bytes[4 + i] = int.parse(id.substring(i * 2, i * 2 + 2), radix: 16);
  }
}

class FileManifest {
  FileManifest(this.id, this.kind, this.name,
      [this.size = 0, this.checksum = 0]) {
    if (!_validId(id) ||
        !RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,62}$').hasMatch(name) ||
        name.contains('..')) {
      throw const FormatException('Invalid file identity');
    }
    _uint32(size);
    _uint32(checksum);
  }
  final String id, name;
  final FileKind kind;
  // Source/final metadata, never encoded by open().
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
  Uint8List open() {
    final b = _frame(FileOp.open, 22 + name.length);
    _id(b, id);
    b[20] = kind.index + 1;
    b[21] = name.length;
    b.setRange(22, b.length, name.codeUnits);
    return b;
  }

  Uint8List close(int handle) {
    _handle(handle);
    final b = _frame(FileOp.close, 14), d = ByteData.sublistView(b);
    d.setUint16(4, handle, Endian.little);
    d.setUint32(6, size, Endian.little);
    d.setUint32(10, checksum, Endian.little);
    return b;
  }

  Uint8List status(int handle, int offset, {bool committed = false}) {
    _handle(handle);
    _uint32(offset);
    final b = _frame(FileOp.status, 31), d = ByteData.sublistView(b);
    _id(b, id);
    d.setUint16(20, handle, Endian.little);
    d.setUint32(22, offset, Endian.little);
    b[26] = committed ? 1 : 0;
    d.setUint32(27, committed ? checksum : 0, Endian.little);
    return b;
  }
}

Uint8List fileData(int handle, int offset, List<int> payload) {
  _handle(handle);
  _uint32(offset);
  if (payload.isEmpty) throw const FormatException('Empty DATA');
  final b = _frame(FileOp.data, fileDataHeader + payload.length),
      d = ByteData.sublistView(b);
  d.setUint16(4, handle, Endian.little);
  d.setUint32(6, offset, Endian.little);
  b.setRange(fileDataHeader, b.length, payload);
  return b;
}

class FilePacket {
  FilePacket.parse(this.bytes) {
    if (bytes.length < 4 ||
        bytes.length > maxFilePacket ||
        bytes[0] != 0 ||
        bytes[1] != 0x84 ||
        bytes[2] != 3 ||
        bytes[3] < 1 ||
        bytes[3] > 4) throw const FormatException('Invalid file packet');
    op = FileOp.values[bytes[3] - 1];
    final d = ByteData.sublistView(bytes);
    if (op == FileOp.open || op == FileOp.status) {
      if (bytes.length < 20) throw const FormatException('Missing identity');
      id = bytes
          .sublist(4, 20)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      if (!_validId(id)) throw const FormatException('Invalid file ID');
    }
    if (op == FileOp.open) {
      manifest();
    } else if (op == FileOp.data) {
      if (bytes.length <= fileDataHeader)
        throw const FormatException('Empty DATA');
      handle = d.getUint16(4, Endian.little);
      offset = d.getUint32(6, Endian.little);
    } else if (op == FileOp.close) {
      if (bytes.length != 14) throw const FormatException('Invalid CLOSE');
      handle = d.getUint16(4, Endian.little);
      offset = d.getUint32(6, Endian.little);
      checksum = d.getUint32(10, Endian.little);
    } else {
      if (bytes.length != 31 || bytes[26] > 1)
        throw const FormatException('Invalid STATUS');
      handle = d.getUint16(20, Endian.little);
      offset = d.getUint32(22, Endian.little);
      committed = bytes[26] == 1;
      checksum = d.getUint32(27, Endian.little);
      if (!committed && checksum != 0)
        throw const FormatException('Unexpected checksum');
    }
    if (op != FileOp.open) _handle(handle);
  }
  final Uint8List bytes;
  late final FileOp op;
  String id = '';
  int handle = 0, offset = 0, checksum = 0;
  bool committed = false;
  FileManifest manifest() {
    if (op != FileOp.open ||
        bytes.length < 23 ||
        bytes[20] < 1 ||
        bytes[20] > 3 ||
        bytes.length != 22 + bytes[21])
      throw const FormatException('Invalid OPEN');
    return FileManifest(id, FileKind.values[bytes[20] - 1],
        String.fromCharCodes(bytes.sublist(22)));
  }

  bool matches(FileManifest m) =>
      op == FileOp.status &&
      id == m.id &&
      offset <= m.size &&
      (!committed || (offset == m.size && checksum == m.checksum));
}
