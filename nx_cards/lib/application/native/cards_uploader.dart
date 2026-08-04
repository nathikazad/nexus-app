// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:nx_cards/application/native/card_outbox_contract.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/clock.dart' as cards;
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final class CardMutationHandler implements offline.MutationHandler {
  const CardMutationHandler({
    required this.localStore,
    required this.transport,
  });

  static const String collectionName = 'cards';

  final LocalCardsStore localStore;
  final CardsSyncTransport transport;

  @override
  String get collection => collectionName;

  @override
  Future<offline.MutationReceipt> execute(
    offline.PendingMutation mutation,
  ) async {
    final cardId = mutation.entityKey.remoteId;
    if (cardId == null) {
      throw const offline.SyncTransportException(
        offline.SyncFailure(
          kind: offline.SyncFailureKind.validation,
          message: 'Cards outbox operation requires a remote card id',
        ),
      );
    }
    final card = await localStore.getCard(cardId);
    if (card == null) {
      throw offline.SyncTransportException(
        offline.SyncFailure(
          kind: offline.SyncFailureKind.validation,
          message: 'Pending card $cardId is missing from the local store',
        ),
      );
    }
    final clientUpdatedAt =
        DateTime.tryParse(
          mutation.payload['client_updated_at']?.toString() ?? '',
        )?.toUtc() ??
        mutation.createdAt.toUtc();
    final result = await (switch (mutation.type) {
      offline.MutationType.update => transport.mutateCard(
        card,
        clientUpdatedAt: clientUpdatedAt,
      ),
      offline.MutationType.delete => transport.deleteCard(
        cardId,
        clientUpdatedAt: clientUpdatedAt,
      ),
      offline.MutationType.create || offline.MutationType.relation =>
        throw const offline.SyncTransportException(
          offline.SyncFailure(
            kind: offline.SyncFailureKind.validation,
            message: 'Unsupported Cards outbox mutation type',
          ),
        ),
    });
    final deckIds = <int>{
      card.deckId,
      for (final revision in result.deckHashes) revision.deckId,
    };
    final manifest = await localStore.deckManifest(deckIds: deckIds);
    final bundle = await transport.syncDecks(
      manifest: manifest,
      deckIds: deckIds,
    );
    return offline.MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey,
      revision: offline.Revision(
        (result.updatedAt ?? clientUpdatedAt).toUtc().toIso8601String(),
      ),
      metadata: <String, Object?>{
        cardMutationStatusMetadataKey: result.status.name,
        cardDeckHashesMetadataKey: result.deckHashes,
        cardSyncBundleMetadataKey: bundle,
      },
    );
  }
}

final class CardsUploader implements offline.SyncStatusSource {
  CardsUploader({
    required LocalCardsStore localStore,
    required CardsSyncTransport transport,
    required cards.Clock clock,
    required String workerId,
    Duration uploadDelay = const Duration(seconds: 2),
  }) : _uploadDelay = uploadDelay {
    final sharedClock = _CardsClock(clock);
    _processor = offline.OutboxProcessor(
      store: localStore,
      handlers: <offline.MutationHandler>[
        CardMutationHandler(localStore: localStore, transport: transport),
      ],
      clock: sharedClock,
      workerId: workerId,
      scheduler: offline.RetryScheduler(clock: sharedClock),
    );
  }

  final Duration _uploadDelay;
  late final offline.OutboxProcessor _processor;

  @override
  offline.SyncStatus get status => _processor.status;

  @override
  Stream<offline.SyncStatus> get statusChanges => _processor.statusChanges;

  void schedule() => _processor.schedule(delay: _uploadDelay);

  Future<offline.OutboxRunResult> uploadPending() => _processor.process();

  Future<void> close() => _processor.close();
}

final class _CardsClock implements offline.Clock {
  const _CardsClock(this.clock);

  final cards.Clock clock;

  @override
  DateTime now() => clock.now();
}
