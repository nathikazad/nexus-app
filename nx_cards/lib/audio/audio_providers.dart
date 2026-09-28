import 'dart:async';
import 'package:nx_cards/audio/audio_store.dart';
import 'package:nx_cards/audio/offline_card_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/account/account_session.dart';
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

  final remote = client == null
      ? null
      : HttpCardAudioRepository(
          baseUrl: baseUrl,
          userId: userId,
          httpClient: client,
        );
  if (!ref.watch(cardsOfflineEnabledProvider) || session == null) return remote;

  final repository = OfflineCardAudioRepository(
    remote: remote,
    store: AudioStore.application(session.account.key),
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final audioDownloadProgressProvider = StreamProvider<AudioDownloadProgress>((
  ref,
) async* {
  final repository = ref.watch(cardAudioRepositoryProvider);
  if (repository is OfflineCardAudioRepository) {
    yield repository.progress;
    yield* repository.changes;
  }
});
