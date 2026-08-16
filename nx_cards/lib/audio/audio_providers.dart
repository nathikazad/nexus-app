import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/audio/cached_card_audio.dart';
import 'package:nx_cards/audio/http_card_audio.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_db/nx_db.dart';

final cardAudioRepositoryProvider = Provider<CardAudioRepository?>((ref) {
  final user = ref.watch(authProvider).value;
  final session = ref.watch(activeCardsSessionProvider).value;
  final preset = user?.preset ?? BackendPreset.fromKey(session?.route);
  final baseUrl = preset == null ? null : resolve(preset).imageHttp;
  final userId = user?.userId ?? session?.userId;
  if (baseUrl == null || userId == null) return null;

  final client = ref.watch(nexusHttpClientProvider);
  if (client == null) return null;

  final remote = HttpCardAudioRepository(
    baseUrl: baseUrl,
    userId: userId,
    httpClient: client,
  );
  if (!ref.watch(cardsOfflineEnabledProvider) || session == null) return remote;

  final safeName = session.account.key.replaceAll(
    RegExp(r'[^a-zA-Z0-9_]'),
    '_',
  );
  final manager = CacheManager(Config('nx_cards_audio_$safeName'));
  ref.onDispose(manager.dispose);
  return CachedCardAudioRepository(
    remote: remote,
    cache: FlutterCardAudioByteCache(manager),
  );
});
