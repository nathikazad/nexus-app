import 'dart:typed_data';

abstract interface class CardAudioRepository {
  Future<Uint8List> fetch(String audioUrl);
}
