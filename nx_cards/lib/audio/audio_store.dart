import 'dart:typed_data';
import 'audio_store_stub.dart'
    if (dart.library.io) 'audio_store_native.dart'
    as platform;
import 'audio_asset.dart';

abstract interface class AudioStore {
  factory AudioStore.application(String account) =
      platform.ApplicationAudioStore;
  Future<Uint8List?> read(AudioAsset asset);
  Future<void> write(AudioAsset asset, Uint8List bytes);
  Future<void> retain(Set<String> hashes);
}
