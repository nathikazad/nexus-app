import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/outbox_coalescer.dart';
import 'package:nx_docs/sync/native/drift_document_mapper.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

class DriftLocalNotesStore implements LocalNotesStore, QueuedDocumentReader {
  DriftLocalNotesStore({
    required this.database,
    required this.accountKey,
    this.mapper = const DriftDocumentMapper(),
    this.coalescer = const OutboxCoalescer(),
    this.files,
  });

  final NotesDatabase database;
  final ContentFiles? files;
  Future<void>? _migration;

  Future<LocalDocumentsCompanion> _toDocumentCompanion(
    LocalDocument local,
  ) async {
    final codec = mapper;
    final row = files != null && local.document.document.length > 32768
        ? await _encodeDocumentOffThread(codec, local)
        : codec.toDocumentCompanion(local);
    final storage = files;
    if (storage == null) return row;
    final reference = await storage.write(
      'documents',
      local.key.localId,
      row.documentJson.value,
    );
    return row.copyWith(documentJson: Value(reference));
  }

  Future<LocalDocument> _fromDocumentRow(LocalDocumentRow row) async {
    final storage = files;
    if (storage == null) return mapper.fromDocumentRow(row);
    final json = await storage.read(row.documentJson);
    if (!isContentReference(row.documentJson)) {
      final reference = await storage.write('documents', row.localId, json);
      await (database.update(database.localDocuments)..where(
            (t) =>
                t.accountKey.equals(accountKey) &
                t.localId.equals(row.localId) &
                t.documentJson.equals(row.documentJson),
          ))
          .write(LocalDocumentsCompanion(documentJson: Value(reference)));
    }
    final decodedRow = row.copyWith(documentJson: json);
    final codec = mapper;
    return json.length > 65536
        ? _decodeDocumentOffThread(codec, decodedRow)
        : codec.fromDocumentRow(decodedRow);
  }

  /// Export one bounded page at a time; interrupted migrations resume safely.
  Future<void> migrateContent() => _migration ??= _migrateContent().catchError((
    Object error,
    StackTrace stack,
  ) {
    _migration = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _migrateContent() async {
    if (files == null) return;
    String after = '';
    while (true) {
      final rows =
          await (database.select(database.localDocuments)
                ..where(
                  (t) =>
                      t.accountKey.equals(accountKey) &
                      t.localId.isBiggerThanValue(after),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.localId)])
                ..limit(25))
              .get();
      if (rows.isEmpty) break;
      for (final row in rows) {
        if (!isContentReference(row.documentJson)) await _fromDocumentRow(row);
      }
      after = rows.last.localId;
    }
    await _migrateAuxiliary('local_snapshots', 'snapshot_id', [
      'document_json',
    ]);
    await _migrateAuxiliary('sync_conflicts', 'local_id', [
      'local_document_json',
      'remote_document_json',
    ]);
  }

  Future<void> _migrateAuxiliary(
    String table,
    String idColumn,
    List<String> columns,
  ) async {
    var after = '';
    while (true) {
      final rows = await database
          .customSelect(
            'SELECT $idColumn, ${columns.join(', ')} FROM $table WHERE account_key=? AND $idColumn>? ORDER BY $idColumn LIMIT 25',
            variables: [Variable(accountKey), Variable(after)],
          )
          .get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        final id = row.read<String>(idColumn);
        for (final column in columns) {
          final old = row.read<String>(column);
          if (isContentReference(old)) continue;
          final reference = await files!.write(table, id, old);
          await database.customStatement(
            'UPDATE $table SET $column=? WHERE account_key=? AND $idColumn=? AND $column=?',
            [reference, accountKey, id, old],
          );
        }
      }
      after = rows.last.read<String>(idColumn);
    }
  }

  @override
  final String accountKey;
  final DriftDocumentMapper mapper;
  final OutboxCoalescer coalescer;

  @override
  Future<LocalDocument?> getDocument(DocumentKey key) async {
    final row = await _documentQuery(key.localId).getSingleOrNull();
    return row == null ? null : await _fromDocumentRow(row);
  }

  Future<LocalDocumentRow?> _rowByRemoteId(int remoteId) =>
      (database.select(database.localDocuments)..where(
            (t) =>
                t.accountKey.equals(accountKey) & t.remoteId.equals(remoteId),
          ))
          .getSingleOrNull();

  @override
  Future<LocalDocument?> getDocumentByRemoteId(int remoteId) async {
    final row =
        await (database.select(database.localDocuments)..where(
              (table) =>
                  table.accountKey.equals(accountKey) &
                  table.remoteId.equals(remoteId),
            ))
            .getSingleOrNull();
    return row == null ? null : await _fromDocumentRow(row);
  }

  @override
  Stream<LocalDocument?> watchDocument(DocumentKey key) {
    return _documentQuery(key.localId).watchSingleOrNull().asyncMap(
      (row) async => row == null ? null : await _fromDocumentRow(row),
    );
  }

  @override
  Stream<List<DocumentSummary>> watchCatalog(CatalogQuery query) {
    if (!query.persistsMembership) {
      final variables = <Variable>[Variable(accountKey)];
      var predicate = 'account_key = ? AND deleted_locally = 0';
      final search = query.searchText.trim().toLowerCase();
      if (search.isNotEmpty) {
        predicate +=
            " AND instr(lower(json_extract(document_json, '\$.title') || ' ' || "
            "json_extract(document_json, '\$.excerpt') || ' ' || "
            "json_extract(document_json, '\$.tags_by_system')), ?) > 0";
        variables.add(Variable(search));
      }
      if (query.tagFilter case final tag?) {
        predicate +=
            " AND EXISTS (SELECT 1 FROM json_each(document_json, '\$.tags_by_system') systems, "
            "json_each(systems.value) tags WHERE systems.key = ? AND tags.value = ?)";
        variables.addAll([Variable(tag.system), Variable(tag.node)]);
      }
      // Filter inside SQLite: do not deserialize every document summary for
      // each search keystroke. Only matching rows cross the isolate boundary.
      return database
          .customSelect(
            'SELECT * FROM document_summaries WHERE $predicate '
            'ORDER BY remote_updated_at DESC, remote_id DESC',
            variables: variables,
            readsFrom: {database.documentSummaries},
          )
          .watch()
          .asyncMap(
            (rows) async => [
              for (final row in rows)
                _summaryFromRow(database.documentSummaries.map(row.data)),
            ],
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
          ..orderBy(<OrderingTerm>[
            OrderingTerm.desc(summaries.remoteUpdatedAt),
            OrderingTerm.desc(summaries.remoteId),
          ]);
    if (query.limit != null) select.limit(query.limit!);
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
        final existing = await _rowByRemoteId(remoteId);
        if (existing == null ||
            existing.syncState == DocumentSyncState.synced.name) {
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
            .insertOnConflictUpdate(await _toDocumentCompanion(local));
        await _upsertBodySummary(
          remote.document,
          deletedLocally: remote.deleted,
        );
      }
    });
  }

  @override
  Future<List<DocumentManifestEntry>> documentManifest() async {
    await migrateContent();
    final table = database.localDocuments;
    final rows =
        await (database.selectOnly(table)
              ..addColumns([table.remoteId, table.serverHash])
              ..where(
                table.accountKey.equals(accountKey) &
                    table.remoteId.isNotNull() &
                    table.deletedLocally.equals(false),
              )
              ..orderBy([OrderingTerm.asc(table.remoteId)]))
            .get();
    return [
      for (final row in rows)
        DocumentManifestEntry(
          documentId: row.read(table.remoteId)!,
          serverHash: row.read(table.serverHash),
        ),
    ];
  }

  @override
  Future<bool> hasCurrentDocument(DocumentManifestEntry entry) async {
    try {
      final row = await _rowByRemoteId(entry.documentId);
      if (row == null) return false;
      // Unsent changes are protected; upload status is reported separately.
      if (row.syncState != DocumentSyncState.synced.name) return true;
      if (entry.serverHash == null || row.serverHash != entry.serverHash) {
        return false;
      }
      final storage = files;
      return storage != null
          ? await storage.exists(row.documentJson)
          : mapper.fromDocumentRow(row).document.hasFullDocument;
    } catch (_) {
      // Missing or invalid local content must be fetched again.
      return false;
    }
  }

  @override
  Future<void> applySyncBundle(DocumentSyncBundle bundle) async {
    await database.transaction(() async {
      for (final remote in bundle.documents) {
        final remoteId = remote.key.remoteId;
        if (remoteId == null) continue;
        final existing = await _rowByRemoteId(remoteId);
        if (bundle.expectedHashes != null &&
            (!bundle.expectedHashes!.containsKey(remoteId) ||
                existing?.serverHash != bundle.expectedHashes![remoteId])) {
          continue;
        }

        if (existing != null &&
            existing.syncState != DocumentSyncState.synced.name) {
          continue;
        }
        final key =
            (existing == null
                ? null
                : DocumentKey(
                    localId: existing.localId,
                    remoteId: existing.remoteId,
                  )) ??
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
            .insertOnConflictUpdate(await _toDocumentCompanion(local));
        await _upsertBodySummary(remote.document);
      }

      for (final remoteId in bundle.deletedIds) {
        final existing = await _rowByRemoteId(remoteId);
        if (bundle.expectedHashes != null &&
            (!bundle.expectedHashes!.containsKey(remoteId) ||
                existing?.serverHash != bundle.expectedHashes![remoteId])) {
          continue;
        }

        if (existing != null &&
            existing.syncState == DocumentSyncState.synced.name) {
          await (database.delete(database.localDocuments)..where(
                (table) =>
                    table.accountKey.equals(accountKey) &
                    table.remoteId.equals(remoteId),
              ))
              .go();
        }
        if (existing == null ||
            existing.syncState == DocumentSyncState.synced.name) {
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
            await _toDocumentCompanion(
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
            await _toDocumentCompanion(
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
      final companion = await _toDocumentCompanion(saved);
      await database
          .into(database.localDocuments)
          .insertOnConflictUpdate(companion);
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
            .insertOnConflictUpdate(
              mapper.toOperationCompanion(
                files == null
                    ? next
                    : next.copyWith(
                        payload: {
                          ...next.payload,
                          'body_ref': companion.documentJson.value,
                        },
                      ),
              ),
            );
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
            await _toDocumentCompanion(
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

  @override
  Future<NxDocument> readQueuedDocument(String reference) async =>
      mapper.documentFromJsonString(await files!.read(reference));

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
            documentJson: mapper.documentToJsonString(
              summary.toDocument().copyWith(
                excerpt: summary.excerpt.length > 320
                    ? summary.excerpt.substring(0, 320)
                    : summary.excerpt,
              ),
            ),
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

    // Membership stores only eligibility. Ordering/limits are applied at read time.
    for (final query in const [
      CatalogQuery.all(),
      CatalogQuery.recent(),
      CatalogQuery.pinned(),
      CatalogQuery.pinned(limit: 50),
      CatalogQuery.books(),
    ]) {
      final eligible =
          !deletedLocally &&
          (query.kind != CatalogKind.pinned || document.pinned) &&
          (query.kind != CatalogKind.books || document.isBook);
      await (database.delete(database.catalogMemberships)..where(
            (t) =>
                t.accountKey.equals(accountKey) &
                t.catalogKey.equals(query.cacheKey) &
                t.remoteId.equals(document.id),
          ))
          .go();
      if (eligible) {
        await database
            .into(database.catalogMemberships)
            .insertOnConflictUpdate(
              CatalogMembershipsCompanion.insert(
                accountKey: accountKey,
                catalogKey: query.cacheKey,
                remoteId: document.id,
                position: 0,
              ),
            );
      }
    }
  }
}

// Keep worker closures outside the store's lexical scope. A closure created
// beside a database callback can otherwise capture its unsendable connection.
Future<LocalDocumentsCompanion> _encodeDocumentOffThread(
  DriftDocumentMapper codec,
  LocalDocument local,
) => Isolate.run(() => codec.toDocumentCompanion(local));

Future<LocalDocument> _decodeDocumentOffThread(
  DriftDocumentMapper codec,
  LocalDocumentRow row,
) => Isolate.run(() => codec.fromDocumentRow(row));
