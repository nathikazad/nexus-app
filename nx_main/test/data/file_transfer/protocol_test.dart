import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/file_transfer/protocol.dart';

void main() {
  final id = '12' * 16;
  test('OPEN contains identity only for every media kind', () {
    for (final kind in FileKind.values) {
      final m = FileManifest(id, kind, 'f.jpg', 3, crc32([97, 98, 99]));
      final packet = FilePacket.parse(m.open());
      expect(packet.bytes.length, 27);
      expect(packet.manifest().id, id);
      expect(packet.manifest().kind, kind);
      expect(m.open(), FileManifest(id, kind, 'f.jpg', 999, 12).open());
    }
  });
  test('DATA uses a handle and offset, with 390 bytes of payload', () {
    final p = FilePacket.parse(fileData(7, 123, List.filled(390, 42)));
    expect(p.bytes.length, 400);
    expect(p.handle, 7);
    expect(p.offset, 123);
    expect(p.id, isEmpty);
    expect(() => fileData(7, 0, List.filled(391, 0)), throwsFormatException);
    expect(() => fileData(0, 0, [1]), throwsFormatException);
    expect(() => fileData(1, 0, []), throwsFormatException);
  });
  test('CLOSE supplies final metadata and STATUS confirms it', () {
    final m =
        FileManifest(id, FileKind.audio, 'a.opusraw', 3, crc32([97, 98, 99]));
    final close = FilePacket.parse(m.close(7));
    expect(close.bytes.length, 14);
    expect(close.handle, 7);
    expect(close.offset, 3);
    expect(close.checksum, 0x352441c2);
    final progress = FilePacket.parse(m.status(7, 2));
    expect(progress.matches(m), true);
    expect(progress.committed, false);
    expect(progress.checksum, 0);
    final done = FilePacket.parse(m.status(7, 3, committed: true));
    expect(done.matches(m), true);
    expect(done.committed, true);
    expect(done.matches(FileManifest('34' * 16, m.kind, m.name, 3, m.checksum)),
        false);
    expect(done.matches(FileManifest(id, m.kind, m.name, 3, 0)), false);
  });
  test('malformed version, handles, names and status flags fail closed', () {
    final m = FileManifest(id, FileKind.photo, 'f.jpg');
    final wrongVersion = m.open()..[2] = 2;
    final badFlag = m.status(1, 0)..[26] = 2;
    final badHandle = m.close(1)..[4] = 0;
    final badName = m.open()..[22] = 0;
    for (final bytes in [
      Uint8List(0),
      wrongVersion,
      badFlag,
      badHandle,
      badName,
      m.close(1).sublist(0, 13)
    ]) {
      expect(() => FilePacket.parse(bytes), throwsFormatException);
    }
  });
  test('wire fixtures use little-endian numbers consistently', () {
    String hex(List<int> b) =>
        b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    expect(hex(FileManifest(id, FileKind.photo, 'f.jpg').open()),
        '00840301${'12' * 16}0105662e6a7067');
    expect(hex(fileData(7, 0x12345678, [97, 98, 99])),
        '00840302070078563412616263');
    expect(
        hex(FileManifest(id, FileKind.photo, 'f.jpg', 3, 0x352441c2).close(7)),
        '00840303070003000000c2412435');
  });
}
