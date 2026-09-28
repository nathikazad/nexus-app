import 'dart:typed_data';
import 'audio_asset.dart';
import 'audio_store.dart';

class ApplicationAudioStore implements AudioStore {
  ApplicationAudioStore(String account);
  @override
  Future<bool> contains(AudioAsset asset) async => false;
  @override
  Future<void> flush() async {}
  @override
  Future<Uint8List?> read(AudioAsset asset) async => null;
  @override
  Future<void> write(AudioAsset asset, Uint8List bytes) async =>
      throw UnsupportedError('Persistent audio requires native storage');
  @override
  Future<void> retain(Set<String> hashes) async {}
}
