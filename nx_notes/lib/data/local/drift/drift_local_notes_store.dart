import 'package:drift/drift.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/outbox_coalescer.dart';
import 'package:nx_notes/data/local/drift/drift_document_mapper.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_summary.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/document_sync.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

class DriftLocalNotesStore implements LocalNotesStore {
  DriftLocalNotesStore({
    required this.database,
    required this.accountKey,
    this.mapper = const DriftDocumentMapper(),
    this.coalescer = const OutboxCoalescer(),
  });

  final NotesDatabase database;
  @override
  final String accountKey;
  final DriftDocumentMapper mapper;
  final OutboxCoalescer coalescer;

  @override
  Future<LocalDocument?> getDocument(DocumentKey key) async {
    final row = await _documentQuery(key.localId).getSingleOrNull();
    return row == null ? null : mapper.fromDocumentRow(row);
  }

  @override
  Future<LocalDocument?> getDocumentByRemoteId(int remoteId) async {
    final row =
        await (database.select(database.localDocuments)..where(
              (table) =>
                  table.accountKey.equals(accountKey) &
                  table.remoteId.equals(remoteId),
            ))
            .getSingleOrNull();
    return row == null ? null : mapper.fromDocumentRow(row);
  }

  @override
  Stream<LocalDocument?> watchDocument(DocumentKey key) {
    return _documentQuery(key.localId).watchSingleOrNull().map(
      (row) => row == null ? null : mapper.fromDocumentRow(row),
    );
  }

  @override
  Stream<List<DocumentSummary>> watchCatalog(CatalogQuery query) {
    if (!query.persistsMembership) {
      final select = database.select(database.documentSummaries)
        ..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.deletedLocally.equals(false),
        )
        ..orderBy(<OrderingTerm Function(DocumentSummaries)>[
          (table) => OrderingTerm.desc(table.remoteUpdatedAt),
        ]);
      return select.watch().map(
        (rows) => _filterSummaries(
          rows.map(_summaryFromRow).toList(growable: false),
          query,
        ),
      );
    }
    final memberships = database.catalogMemberships;
    final summaries = database.documentSummaries;
    final select =
        database.select(memberships).join(<Join>[
            innerJoin(
              summaries,
              summaries.accountKey.equalsExp(memberships.accountKey) &
                  summaries.remoteId.equalsExp(memberships.remoteId),
            ),
          ])
          ..where(
            memberships.accountKey.equals(accountKey) &
                memberships.catalogKey.equals(query.cacheKey) &
                summaries.deletedLocally.equals(false),
          )
          ..orderBy(<OrderingTerm>[OrderingTerm.asc(memberships.position)]);
    return select.watch().map(
      (rows) => <DocumentSummary>[
        for (final row in rows) _summaryFromRow(row.readTable(summaries)),
      ],
    );
  }

  @override
  Future<List<DocumentSummary>> readCatalog(CatalogQuery query) {
    return watchCatalog(query).first;
  }

  @override
  Future<void> replaceCatalog(
    CatalogQuery query,
    List<DocumentSummary> summaries,
  ) async {
    if (!query.persistsMembership) return;
    await database.transaction(() async {
      await (database.delete(database.catalogMemberships)..where(
            (table) =>
                table.accountKey.equals(accountKey) &
                table.catalogKey.equals(query.cacheKey),
          ))
          .go();
      for (var index = 0; index < summaries.length; index++) {
        final summary = summaries[index];
        final remoteId = summary.id;
        final existing = await getDocumentByRemoteId(remoteId);
        if (existing == null ||
            existing.syncState == DocumentSyncState.synced) {
          await _upsertSummary(summary);
        }
        await database
            .into(database.catalogMemberships)
            .insertOnConflictUpdate(
              CatalogMembershipsCompanion.insert(
                accountKey: accountKey,
                catalogKey: query.cacheKey,
                remoteId: remoteId,
                position: index,
              ),
            );
      }
    });
  }

  @override
  Future<void> importRemoteDocuments(List<RemoteDocument> documents) async {
    await database.transaction(() async {
      for (final remote in documents) {
        final existing = await _documentQuery(
          remote.key.localId,
        ).getSingleOrNull();
        if (existing != null &&
            DocumentSyncState.values.byName(existing.syncState) !=
                DocumentSyncState.synced) {
          continue;
        }
        final local = LocalDocument(
          key: remote.key,
          accountKey: accountKey,
          document: remote.document,
          localUpdatedAt: remote.document.updatedAt,
          serverRevision: remote.revision,
          baseServerRevision: remote.revision,
          serverHash: remote.serverHash,
          syncState: DocumentSyncState.synced,
          deletedLocally: remote.deleted,
        );
        await database
            .into(database.localDocuments)
            .insertOnConflictUpdate(mapper.toDocumentCompanion(local));
        await _upsertBodySummary(
          remote.document,
          deletedLocally: remote.deleted,
        );
      }
    });
  }

  @override
  Future<List<DocumentManifestEntry>> documentManifest() async {
    final rows =
        await (database.select(database.localDocuments)
              ..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.remoteId.isNotNull() &
                    table.deletedLocally.equals(false),
              )
              ..orderBy(<OrderingTerm Function(LocalDocuments)>[
                (table) => OrderingTerm.asc(table.remoteId),
              ]))
            .get();
    return <DocumentManifestEntry>[
      for (final row in rows)
        DocumentManifestEntry(
          documentId: row.remoteId!,
          serverHash: row.serverHash,
        ),
    ];
  }

  @override
  Future<void> applySyncBundle(DocumentSyncBundle bundle) async {
    await database.transaction(() async {
      for (final remote in bundle.documents) {
        final remoteId = remote.key.remoteId;
        if (remoteId == null) continue;
        final existing = await getDocumentByRemoteId(remoteId);
        if (existing != null &&
            existing.syncState != DocumentSyncState.synced) {
          continue;
        }
        final key =
            existing?.key ??
            DocumentKey(localId: 'remote-$remoteId', remoteId: remoteId);
        final local = LocalDocument(
          key: key,
          accountKey: accountKey,
          document: remote.document,
          localUpdatedAt: remote.document.updatedAt,
          serverRevision: remote.revision,
          baseServerRevision: remote.revision,
          serverHash: remote.serverHash,
          syncState: DocumentSyncState.synced,
        );
        await database
            .into(database.localDocuments)
            .insertOnConflictUpdate(mapper.toDocumentCompanion(local));
        await _upsertBodySummary(remote.document);
      }

      for (final remoteId in bundle.deletedIds) {
        final existing = await getDocumentByRemoteId(remoteId);
        if (existing != null &&
            existing.syncState == DocumentSyncState.synced) {
          await (database.delete(database.localDocuments)..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.remoteId.equals(remoteId),
              ))
              .go();
        }
        if (existing == null ||
            existing.syncState == DocumentSyncState.synced) {
          await (database.delete(database.documentSummaries)..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.remoteId.equals(remoteId),
              ))
              .go();
          await (database.delete(database.catalogMemberships)..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.remoteId.equals(remoteId),
              ))
              .go();
        }
      }

      await _rebuildDefaultCatalogs();
    });
  }

  @override
  Future<void> discardPendingAndImportRemote(RemoteDocument remote) async {
    final remoteId = remote.key.remoteId;
    if (remoteId == null) {
      throw ArgumentError('stale replacement requires a remote id');
    }
    await database.transaction(() async {
      final existing = await getDocumentByRemoteId(remoteId);
      final stableKey = existing?.key ?? remote.key;
      if (existing != null) {
        await (database.delete(database.syncOutbox)..where(
              (table) =>
                  table.accountKey.equals(accountKey) &
                  table.aggregateId.equals(existing.key.localId),
            ))
            .go();
        await (database.delete(database.syncConflicts)..where(
              (table) =>
                  table.accountKey.equals(accountKey) &
                  table.localId.equals(existing.key.localId),
            ))
            .go();
      }
      await database
          .into(database.localDocuments)
          .insertOnConflictUpdate(
            mapper.toDocumentCompanion(
              LocalDocument(
                key: stableKey,
                accountKey: accountKey,
                document: remote.document,
                localUpdatedAt: remote.document.updatedAt,
                serverRevision: remote.revision,
                baseServerRevision: remote.revision,
                serverHash: remote.serverHash,
                syncState: DocumentSyncState.synced,
                deletedLocally: remote.deleted,
              ),
            ),
          );
      await _upsertBodySummary(remote.document, deletedLocally: remote.deleted);
    });
  }

  @override
  Future<bool> discardStaleOperationAndImportRemote(
    String operationId,
    RemoteDocument remote,
  ) {
    return database.transaction(() async {
      final operation = await _operationById(operationId);
      if (operation == null) return false;
      final existing = await _documentQuery(
        operation.aggregateId,
      ).getSingleOrNull();
      if (existing == null) return false;
      await (database.delete(
        database.syncOutbox,
      )..where((table) => table.operationId.equals(operationId))).go();
      await (database.delete(database.syncConflicts)..where(
            (table) =>
                table.accountKey.equals(accountKey) &
                table.localId.equals(operation.aggregateId),
          ))
          .go();
      final revision = remote.revision;
      await database
          .into(database.localDocuments)
          .insertOnConflictUpdate(
            mapper.toDocumentCompanion(
              LocalDocument(
                key: DocumentKey(
                  localId: operation.aggregateId,
                  remoteId: remote.key.remoteId,
                ),
                accountKey: accountKey,
                document: remote.document,
                localUpdatedAt: remote.document.updatedAt,
                serverRevision: revision,
                baseServerRevision: revision,
                serverHash: remote.serverHash,
                syncState: DocumentSyncState.synced,
                deletedLocally: remote.deleted,
              ),
            ),
          );
      await _upsertBodySummary(remote.document, deletedLocally: remote.deleted);
      return true;
    });
  }

  @override
  Future<void> saveDraftAndEnqueue(
    LocalDocument document, {
    required PendingOperation operation,
  }) async {
    _validateWrite(document, operation);
    await database.transaction(() async {
      final existingRow = await _operationForDocument(document.key.localId);
      final existing = existingRow == null
          ? null
          : mapper.fromOperationRow(
              existingRow,
              remoteId: document.key.remoteId,
            );
      final next = existing == null
          ? operation
          : coalescer.coalesce(existing, operation);
      final saved = document.copyWith(
        syncState: next == null
            ? DocumentSyncState.synced
            : DocumentSyncState.queued,
      );
      await database
          .into(database.localDocuments)
          .insertOnConflictUpdate(mapper.toDocumentCompanion(saved));
      final remoteId = saved.key.remoteId;
      if (remoteId != null) {
        await _upsertBodySummary(
          saved.document,
          deletedLocally: saved.deletedLocally,
        );
      }
      if (existingRow != null) {
        await (database.delete(database.syncOutbox)..where(
              (table) => table.operationId.equals(existingRow.operationId),
            ))
            .go();
      }
      if (next != null) {
        await database
            .into(database.syncOutbox)
            .insertOnConflictUpdate(mapper.toOperationCompanion(next));
      }
    });
  }

  @override
  Future<List<PendingOperation>> pendingOperations() async {
    final rows =
        await (database.select(database.syncOutbox)
              ..where((table) => table.accountKey.equals(accountKey))
              ..orderBy(<OrderingTerm Function(SyncOutbox)>[
                (table) => OrderingTerm.asc(table.createdAt),
              ]))
            .get();
    return Future.wait(rows.map(_operationFromRow));
  }

  @override
  Future<PendingOperation?> claimNextOperation({
    required String workerId,
    required Duration lease,
    required DateTime now,
  }) {
    if (lease <= Duration.zero) {
      throw ArgumentError.value(lease, 'lease', 'must be positive');
    }
    return database.transaction(() async {
      final rows =
          await (database.select(database.syncOutbox)
                ..where((table) => table.accountKey.equals(accountKey))
                ..orderBy(<OrderingTerm Function(SyncOutbox)>[
                  (table) => OrderingTerm.asc(table.createdAt),
                ]))
              .get();
      for (final row in rows) {
        final operation = await _operationFromRow(row);
        if (!operation.isEligibleAt(now)) continue;
        final claimed = operation.copyWith(
          status: PendingOperationStatus.claimed,
          leaseOwner: workerId,
          leaseExpiresAt: now.add(lease),
          clearNextAttemptAt: true,
        );
        await (database.update(database.syncOutbox)
              ..where((table) => table.operationId.equals(row.operationId)))
            .write(mapper.toOperationCompanion(claimed));
        await _setDocumentSyncState(
          operation.documentKey.localId,
          DocumentSyncState.syncing,
        );
        return claimed;
      }
      return null;
    });
  }

  @override
  Future<void> completeOperation(
    String operationId, {
    required RemoteWriteResult result,
  }) async {
    await database.transaction(() async {
      final row = await _operationById(operationId);
      if (row == null) return;
      await (database.update(database.localDocuments)..where(
            (table) =>
                table.accountKey.equals(accountKey) &
                table.localId.equals(row.aggregateId),
          ))
          .write(
            LocalDocumentsCompanion(
              remoteId: Value<int?>(result.key.remoteId),
              serverRevision: Value<String?>(result.revision.value),
              baseServerRevision: Value<String?>(result.revision.value),
              serverHash: Value<String?>(result.serverHash),
              syncState: Value<String>(DocumentSyncState.synced.name),
            ),
          );
      await (database.delete(
        database.syncOutbox,
      )..where((table) => table.operationId.equals(operationId))).go();
    });
  }

  @override
  Future<void> completeCreateOperation(
    String operationId, {
    required RemoteDocument document,
  }) async {
    await database.transaction(() async {
      final row = await _operationById(operationId);
      if (row == null) return;
      final existing = await _documentQuery(row.aggregateId).getSingleOrNull();
      if (existing == null) return;
      final revision = document.revision;
      await database
          .into(database.localDocuments)
          .insertOnConflictUpdate(
            mapper.toDocumentCompanion(
              LocalDocument(
                key: DocumentKey(
                  localId: row.aggregateId,
                  remoteId: document.key.remoteId,
                ),
                accountKey: accountKey,
                document: document.document,
                localUpdatedAt: document.document.updatedAt,
                serverRevision: revision,
                baseServerRevision: revision,
                serverHash: document.serverHash,
                syncState: DocumentSyncState.synced,
              ),
            ),
          );
      await _upsertBodySummary(document.document);
      await (database.delete(
        database.syncOutbox,
      )..where((table) => table.operationId.equals(operationId))).go();
    });
  }

  @override
  Future<void> failOperation(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) async {
    await database.transaction(() async {
      final row = await _operationById(operationId);
      if (row == null) return;
      final operation = await _operationFromRow(row);
      final failed = operation.copyWith(
        status: failure.isRetryable
            ? PendingOperationStatus.retryWaiting
            : PendingOperationStatus.blocked,
        attemptCount: operation.attemptCount + 1,
        nextAttemptAt: retryAt,
        clearLeaseOwner: true,
        clearLeaseExpiresAt: true,
        lastError: failure.message,
      );
      await (database.update(database.syncOutbox)
            ..where((table) => table.operationId.equals(operationId)))
          .write(mapper.toOperationCompanion(failed));
      await _setDocumentSyncState(
        row.aggregateId,
        failure.kind == SyncFailureKind.conflict
            ? DocumentSyncState.conflict
            : DocumentSyncState.retryWaiting,
      );
    });
  }

  SimpleSelectStatement<$LocalDocumentsTable, LocalDocumentRow> _documentQuery(
    String localId,
  ) {
    return database.select(database.localDocuments)..where(
      (table) =>
          table.accountKey.equals(accountKey) & table.localId.equals(localId),
    );
  }

  Future<SyncOutboxData?> _operationForDocument(String localId) {
    return (database.select(database.syncOutbox)..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.aggregateId.equals(localId),
        ))
        .getSingleOrNull();
  }

  Future<SyncOutboxData?> _operationById(String operationId) {
    return (database.select(database.syncOutbox)..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  Future<PendingOperation> _operationFromRow(SyncOutboxData row) async {
    final document = await _documentQuery(row.aggregateId).getSingleOrNull();
    return mapper.fromOperationRow(row, remoteId: document?.remoteId);
  }

  Future<void> _setDocumentSyncState(
    String localId,
    DocumentSyncState state,
  ) async {
    await (database.update(database.localDocuments)..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.localId.equals(localId),
        ))
        .write(LocalDocumentsCompanion(syncState: Value<String>(state.name)));
  }

  void _validateWrite(LocalDocument document, PendingOperation operation) {
    if (document.accountKey != accountKey ||
        operation.accountKey != accountKey) {
      throw StateError('write belongs to a different account');
    }
    if (document.key != operation.documentKey) {
      throw StateError('document and operation keys do not match');
    }
  }

  DocumentSummary _summaryFromRow(DocumentSummaryRow row) {
    return DocumentSummary.fromDocument(
      mapper.documentFromJsonString(row.documentJson),
    );
  }

  Future<void> _upsertSummary(
    DocumentSummary summary, {
    bool deletedLocally = false,
  }) {
    return database
        .into(database.documentSummaries)
        .insertOnConflictUpdate(
          DocumentSummariesCompanion.insert(
            accountKey: accountKey,
            remoteId: summary.id,
            documentJson: mapper.documentToJsonString(summary.toDocument()),
            remoteUpdatedAt: summary.updatedAt,
            deletedLocally: Value<bool>(deletedLocally),
          ),
        );
  }

  Future<void> _upsertBodySummary(
    NxDocument document, {
    bool deletedLocally = false,
  }) async {
    final summary = DocumentSummary.fromDocument(document);
    await _upsertSummary(summary, deletedLocally: deletedLocally);

    final membershipRows =
        await (database.select(database.catalogMemberships)..where(
              (table) =>
                  table.accountKey.equals(accountKey) &
                  table.catalogKey.like('pinned:%'),
            ))
            .get();
    final catalogKeys = <String>{
      const CatalogQuery.pinned().cacheKey,
      const CatalogQuery.pinned(limit: 50).cacheKey,
      for (final row in membershipRows) row.catalogKey,
    };
    await (database.delete(database.catalogMemberships)..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.catalogKey.like('pinned:%') &
              table.remoteId.equals(document.id),
        ))
        .go();
    if (!document.pinned || deletedLocally) return;
    for (final catalogKey in catalogKeys) {
      await database
          .into(database.catalogMemberships)
          .insertOnConflictUpdate(
            CatalogMembershipsCompanion.insert(
              accountKey: accountKey,
              catalogKey: catalogKey,
              remoteId: document.id,
              position: -1,
            ),
          );
    }
  }

  Future<void> _rebuildDefaultCatalogs() async {
    final rows =
        await (database.select(database.documentSummaries)
              ..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.deletedLocally.equals(false),
              )
              ..orderBy(<OrderingTerm Function(DocumentSummaries)>[
                (table) => OrderingTerm.desc(table.remoteUpdatedAt),
              ]))
            .get();
    final summaries = rows.map(_summaryFromRow).toList(growable: false);
    await _replaceMembershipRows(const CatalogQuery.all(), summaries);
    await _replaceMembershipRows(
      const CatalogQuery.recent(),
      summaries.take(20).toList(growable: false),
    );
    await _replaceMembershipRows(
      const CatalogQuery.pinned(),
      summaries
          .where((summary) => summary.pinned)
          .take(20)
          .toList(growable: false),
    );
    await _replaceMembershipRows(
      const CatalogQuery.books(),
      summaries.where((summary) => summary.isBook).toList(growable: false),
    );
  }

  Future<void> _replaceMembershipRows(
    CatalogQuery query,
    List<DocumentSummary> summaries,
  ) async {
    await (database.delete(database.catalogMemberships)..where(
          (table) =>
              table.accountKey.equals(accountKey) &
              table.catalogKey.equals(query.cacheKey),
        ))
        .go();
    for (var index = 0; index < summaries.length; index++) {
      await database
          .into(database.catalogMemberships)
          .insert(
            CatalogMembershipsCompanion.insert(
              accountKey: accountKey,
              catalogKey: query.cacheKey,
              remoteId: summaries[index].id,
              position: index,
            ),
          );
    }
  }

  List<DocumentSummary> _filterSummaries(
    List<DocumentSummary> rows,
    CatalogQuery query,
  ) {
    final search = query.searchText.trim().toLowerCase();
    return rows
        .where((summary) {
          if (search.isNotEmpty &&
              !<String>[
                summary.title,
                summary.excerpt,
                ...summary.tagsBySystem.values.expand((tags) => tags),
              ].join(' ').toLowerCase().contains(search)) {
            return false;
          }
          final tag = query.tagFilter;
          if (tag != null &&
              !(summary.tagsBySystem[tag.system]?.contains(tag.node) ??
                  false)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}
