import 'package:drift/drift.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/outbox_coalescer.dart';
import 'package:nx_notes/data/local/drift/drift_document_mapper.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';
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
  Stream<LocalDocument?> watchDocument(DocumentKey key) {
    return _documentQuery(key.localId).watchSingleOrNull().map(
      (row) => row == null ? null : mapper.fromDocumentRow(row),
    );
  }

  @override
  Stream<List<LocalDocument>> watchDocuments(DocumentQuery query) {
    final select = database.select(database.localDocuments)
      ..where(
        (table) =>
            table.accountKey.equals(accountKey) &
            table.deletedLocally.equals(false),
      )
      ..orderBy(<OrderingTerm Function(LocalDocuments)>[
        (table) => OrderingTerm.desc(table.localUpdatedAt),
      ]);
    return select.watch().map((rows) {
      final documents = rows.map(mapper.fromDocumentRow).toList();
      return _filterDocuments(documents, query);
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
          syncState: DocumentSyncState.synced,
          deletedLocally: remote.deleted,
        );
        await database
            .into(database.localDocuments)
            .insertOnConflictUpdate(mapper.toDocumentCompanion(local));
      }
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
      if (row == null) {
        throw StateError('pending operation not found: $operationId');
      }
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
              syncState: Value<String>(DocumentSyncState.synced.name),
            ),
          );
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
      if (row == null) {
        throw StateError('pending operation not found: $operationId');
      }
      final operation = await _operationFromRow(row);
      final failed = operation.copyWith(
        status: PendingOperationStatus.retryWaiting,
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

  @override
  Future<String?> readSyncCursor() async {
    final row = await (database.select(
      database.syncMetadata,
    )..where((table) => table.accountKey.equals(accountKey))).getSingleOrNull();
    return row?.cursor;
  }

  @override
  Future<void> writeSyncCursor(String cursor) async {
    await database
        .into(database.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion(
            accountKey: Value<String>(accountKey),
            cursor: Value<String?>(cursor),
          ),
        );
  }

  @override
  Future<void> recordConflict(SyncConflict conflict) async {
    await database.transaction(() async {
      await database
          .into(database.syncConflicts)
          .insertOnConflictUpdate(
            SyncConflictsCompanion(
              accountKey: Value<String>(accountKey),
              localId: Value<String>(conflict.documentKey.localId),
              localDocumentJson: Value<String>(
                mapper.documentToJsonString(conflict.localDocument),
              ),
              remoteDocumentJson: Value<String>(
                mapper.documentToJsonString(conflict.remoteDocument),
              ),
              remoteRevision: Value<String>(conflict.remoteRevision.value),
              detectedAt: Value<DateTime>(conflict.detectedAt),
            ),
          );
      await _setDocumentSyncState(
        conflict.documentKey.localId,
        DocumentSyncState.conflict,
      );
    });
  }

  @override
  Future<List<SyncConflict>> conflicts() async {
    final rows =
        await (database.select(database.syncConflicts)
              ..where((table) => table.accountKey.equals(accountKey))
              ..orderBy(<OrderingTerm Function(SyncConflicts)>[
                (table) => OrderingTerm.asc(table.detectedAt),
              ]))
            .get();
    return <SyncConflict>[
      for (final row in rows)
        SyncConflict(
          documentKey: DocumentKey(localId: row.localId),
          localDocument: mapper.documentFromJsonString(row.localDocumentJson),
          remoteDocument: mapper.documentFromJsonString(row.remoteDocumentJson),
          remoteRevision: RemoteRevision(row.remoteRevision),
          detectedAt: row.detectedAt,
        ),
    ];
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

  List<LocalDocument> _filterDocuments(
    List<LocalDocument> rows,
    DocumentQuery query,
  ) {
    final search = query.searchText.trim().toLowerCase();
    return rows.where((local) {
      final document = local.document;
      if (query.pinnedOnly && !document.pinned) return false;
      if (search.isNotEmpty &&
          !<String>[
            document.title,
            document.document,
            document.excerpt,
          ].join(' ').toLowerCase().contains(search)) {
        return false;
      }
      for (final filter in query.tagFilters) {
        final tags = document.tagsBySystem[filter.system] ?? const <String>[];
        if (!tags.contains(filter.node)) return false;
      }
      return true;
    }).toList();
  }
}
