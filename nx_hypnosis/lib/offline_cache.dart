import 'dart:convert';
import 'package:nx_offline/nx_offline_storage.dart';
import 'desires.dart';

/// Reuses the same atomic, account-scoped content and binary stores as Books.
class HypnosisCache {
  HypnosisCache(this.library, this.recordings);
  factory HypnosisCache.application(String account) => HypnosisCache(
    FileLibrary.application(account),
    BinaryContentFiles.application(account),
  );
  final FileLibrary library;
  final BinaryContentFiles recordings;

  Future<String?> readCollection() => library.read('hypnosis', 'collection');
  Future<void> saveCollection(String body) async {
    try {
      if (await readCollection() == body) return;
    } on Exception {
      /* Replace corrupt cached content. */
    }
    await library.saveRemote('hypnosis', 'collection', body);
  }

  String _key(Tape tape) =>
      jsonEncode([tape.id, tape.audioAsset, tape.audioRevision]);

  Future<String?> recordingPath(Tape tape) async {
    try {
      final encoded = await library.read('recordings', _key(tape));
      if (encoded == null) return null;
      final reference = BinaryContentReference.decode(encoded);
      if (!await recordings.verify(reference)) return null;
      return recordings.localPath(reference);
    } on Exception {
      return null;
    }
  }

  Future<String> saveRecording(Tape tape, Stream<List<int>> bytes) async {
    final reference = await recordings.write(
      'hypnosis',
      tape.id,
      '.mp3',
      bytes,
    );
    await library.saveRemote('recordings', _key(tape), reference.encode());
    return recordings.localPath(reference);
  }

  Future<void> close() => library.close();
}
