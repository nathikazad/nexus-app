import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nx_cards/browser/browser.dart';

abstract interface class CardAudioByteCache {
  Future<Uint8List?> read(String key);

  Future<void> write(String key, Uint8List bytes);
}

final class CachedCardAudioRepository implements CardAudioRepository {
  const CachedCardAudioRepository({required this.remote, required this.cache});

  final CardAudioRepository remote;
  final CardAudioByteCache cache;

  @override
  Future<Uint8List> fetch(String audioUrl) async {
    final cached = await cache.read(audioUrl);
    if (cached != null && cached.isNotEmpty) return cached;
    final bytes = await remote.fetch(audioUrl);
    try {
      await cache.write(audioUrl, bytes);
    } catch (_) {
      // A cache failure must not prevent freshly downloaded audio from
      // playing. A later background sync will retry persisting the file.
    }
    return bytes;
  }
}

final class FlutterCardAudioByteCache implements CardAudioByteCache {
  const FlutterCardAudioByteCache(this.manager);

  final BaseCacheManager manager;

  @override
  Future<Uint8List?> read(String key) async {
    final cached = await manager.getFileFromCache(key);
    if (cached == null || !await cached.file.exists()) return null;
    return cached.file.readAsBytes();
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    await manager.putFile(key, bytes, fileExtension: 'mp3');
  }
}
