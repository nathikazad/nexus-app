// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_database.dart';

// ignore_for_file: type=lint
class $LocalDocumentsTable extends LocalDocuments
    with TableInfo<$LocalDocumentsTable, LocalDocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<String> serverRevision = GeneratedColumn<String>(
    'server_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseServerRevisionMeta =
      const VerificationMeta('baseServerRevision');
  @override
  late final GeneratedColumn<String> baseServerRevision =
      GeneratedColumn<String>(
        'base_server_revision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedLocallyMeta = const VerificationMeta(
    'deletedLocally',
  );
  @override
  late final GeneratedColumn<bool> deletedLocally = GeneratedColumn<bool>(
    'deleted_locally',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted_locally" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    remoteId,
    accountKey,
    documentJson,
    localUpdatedAt,
    serverRevision,
    baseServerRevision,
    syncState,
    deletedLocally,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentJsonMeta);
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    if (data.containsKey('base_server_revision')) {
      context.handle(
        _baseServerRevisionMeta,
        baseServerRevision.isAcceptableOrUnknown(
          data['base_server_revision']!,
          _baseServerRevisionMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('deleted_locally')) {
      context.handle(
        _deletedLocallyMeta,
        deletedLocally.isAcceptableOrUnknown(
          data['deleted_locally']!,
          _deletedLocallyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId, accountKey};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountKey, remoteId},
  ];
  @override
  LocalDocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDocumentRow(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      ),
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      )!,
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_revision'],
      ),
      baseServerRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_server_revision'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      deletedLocally: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted_locally'],
      )!,
    );
  }

  @override
  $LocalDocumentsTable createAlias(String alias) {
    return $LocalDocumentsTable(attachedDatabase, alias);
  }
}

class LocalDocumentRow extends DataClass
    implements Insertable<LocalDocumentRow> {
  final String localId;
  final int? remoteId;
  final String accountKey;
  final String documentJson;
  final DateTime localUpdatedAt;
  final String? serverRevision;
  final String? baseServerRevision;
  final String syncState;
  final bool deletedLocally;
  const LocalDocumentRow({
    required this.localId,
    this.remoteId,
    required this.accountKey,
    required this.documentJson,
    required this.localUpdatedAt,
    this.serverRevision,
    this.baseServerRevision,
    required this.syncState,
    required this.deletedLocally,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['account_key'] = Variable<String>(accountKey);
    map['document_json'] = Variable<String>(documentJson);
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    if (!nullToAbsent || serverRevision != null) {
      map['server_revision'] = Variable<String>(serverRevision);
    }
    if (!nullToAbsent || baseServerRevision != null) {
      map['base_server_revision'] = Variable<String>(baseServerRevision);
    }
    map['sync_state'] = Variable<String>(syncState);
    map['deleted_locally'] = Variable<bool>(deletedLocally);
    return map;
  }

  LocalDocumentsCompanion toCompanion(bool nullToAbsent) {
    return LocalDocumentsCompanion(
      localId: Value(localId),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      accountKey: Value(accountKey),
      documentJson: Value(documentJson),
      localUpdatedAt: Value(localUpdatedAt),
      serverRevision: serverRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(serverRevision),
      baseServerRevision: baseServerRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseServerRevision),
      syncState: Value(syncState),
      deletedLocally: Value(deletedLocally),
    );
  }

  factory LocalDocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDocumentRow(
      localId: serializer.fromJson<String>(json['localId']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      documentJson: serializer.fromJson<String>(json['documentJson']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      serverRevision: serializer.fromJson<String?>(json['serverRevision']),
      baseServerRevision: serializer.fromJson<String?>(
        json['baseServerRevision'],
      ),
      syncState: serializer.fromJson<String>(json['syncState']),
      deletedLocally: serializer.fromJson<bool>(json['deletedLocally']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'remoteId': serializer.toJson<int?>(remoteId),
      'accountKey': serializer.toJson<String>(accountKey),
      'documentJson': serializer.toJson<String>(documentJson),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'serverRevision': serializer.toJson<String?>(serverRevision),
      'baseServerRevision': serializer.toJson<String?>(baseServerRevision),
      'syncState': serializer.toJson<String>(syncState),
      'deletedLocally': serializer.toJson<bool>(deletedLocally),
    };
  }

  LocalDocumentRow copyWith({
    String? localId,
    Value<int?> remoteId = const Value.absent(),
    String? accountKey,
    String? documentJson,
    DateTime? localUpdatedAt,
    Value<String?> serverRevision = const Value.absent(),
    Value<String?> baseServerRevision = const Value.absent(),
    String? syncState,
    bool? deletedLocally,
  }) => LocalDocumentRow(
    localId: localId ?? this.localId,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    accountKey: accountKey ?? this.accountKey,
    documentJson: documentJson ?? this.documentJson,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    serverRevision: serverRevision.present
        ? serverRevision.value
        : this.serverRevision,
    baseServerRevision: baseServerRevision.present
        ? baseServerRevision.value
        : this.baseServerRevision,
    syncState: syncState ?? this.syncState,
    deletedLocally: deletedLocally ?? this.deletedLocally,
  );
  LocalDocumentRow copyWithCompanion(LocalDocumentsCompanion data) {
    return LocalDocumentRow(
      localId: data.localId.present ? data.localId.value : this.localId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
      baseServerRevision: data.baseServerRevision.present
          ? data.baseServerRevision.value
          : this.baseServerRevision,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      deletedLocally: data.deletedLocally.present
          ? data.deletedLocally.value
          : this.deletedLocally,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDocumentRow(')
          ..write('localId: $localId, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountKey: $accountKey, ')
          ..write('documentJson: $documentJson, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('baseServerRevision: $baseServerRevision, ')
          ..write('syncState: $syncState, ')
          ..write('deletedLocally: $deletedLocally')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    remoteId,
    accountKey,
    documentJson,
    localUpdatedAt,
    serverRevision,
    baseServerRevision,
    syncState,
    deletedLocally,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDocumentRow &&
          other.localId == this.localId &&
          other.remoteId == this.remoteId &&
          other.accountKey == this.accountKey &&
          other.documentJson == this.documentJson &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.serverRevision == this.serverRevision &&
          other.baseServerRevision == this.baseServerRevision &&
          other.syncState == this.syncState &&
          other.deletedLocally == this.deletedLocally);
}

class LocalDocumentsCompanion extends UpdateCompanion<LocalDocumentRow> {
  final Value<String> localId;
  final Value<int?> remoteId;
  final Value<String> accountKey;
  final Value<String> documentJson;
  final Value<DateTime> localUpdatedAt;
  final Value<String?> serverRevision;
  final Value<String?> baseServerRevision;
  final Value<String> syncState;
  final Value<bool> deletedLocally;
  final Value<int> rowid;
  const LocalDocumentsCompanion({
    this.localId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.baseServerRevision = const Value.absent(),
    this.syncState = const Value.absent(),
    this.deletedLocally = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDocumentsCompanion.insert({
    required String localId,
    this.remoteId = const Value.absent(),
    required String accountKey,
    required String documentJson,
    required DateTime localUpdatedAt,
    this.serverRevision = const Value.absent(),
    this.baseServerRevision = const Value.absent(),
    required String syncState,
    this.deletedLocally = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       accountKey = Value(accountKey),
       documentJson = Value(documentJson),
       localUpdatedAt = Value(localUpdatedAt),
       syncState = Value(syncState);
  static Insertable<LocalDocumentRow> custom({
    Expression<String>? localId,
    Expression<int>? remoteId,
    Expression<String>? accountKey,
    Expression<String>? documentJson,
    Expression<DateTime>? localUpdatedAt,
    Expression<String>? serverRevision,
    Expression<String>? baseServerRevision,
    Expression<String>? syncState,
    Expression<bool>? deletedLocally,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (remoteId != null) 'remote_id': remoteId,
      if (accountKey != null) 'account_key': accountKey,
      if (documentJson != null) 'document_json': documentJson,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (baseServerRevision != null)
        'base_server_revision': baseServerRevision,
      if (syncState != null) 'sync_state': syncState,
      if (deletedLocally != null) 'deleted_locally': deletedLocally,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDocumentsCompanion copyWith({
    Value<String>? localId,
    Value<int?>? remoteId,
    Value<String>? accountKey,
    Value<String>? documentJson,
    Value<DateTime>? localUpdatedAt,
    Value<String?>? serverRevision,
    Value<String?>? baseServerRevision,
    Value<String>? syncState,
    Value<bool>? deletedLocally,
    Value<int>? rowid,
  }) {
    return LocalDocumentsCompanion(
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      accountKey: accountKey ?? this.accountKey,
      documentJson: documentJson ?? this.documentJson,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      baseServerRevision: baseServerRevision ?? this.baseServerRevision,
      syncState: syncState ?? this.syncState,
      deletedLocally: deletedLocally ?? this.deletedLocally,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<String>(serverRevision.value);
    }
    if (baseServerRevision.present) {
      map['base_server_revision'] = Variable<String>(baseServerRevision.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (deletedLocally.present) {
      map['deleted_locally'] = Variable<bool>(deletedLocally.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDocumentsCompanion(')
          ..write('localId: $localId, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountKey: $accountKey, ')
          ..write('documentJson: $documentJson, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('baseServerRevision: $baseServerRevision, ')
          ..write('syncState: $syncState, ')
          ..write('deletedLocally: $deletedLocally, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggregateIdMeta = const VerificationMeta(
    'aggregateId',
  );
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
    'aggregate_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<String> baseRevision = GeneratedColumn<String>(
    'base_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseExpiresAtMeta = const VerificationMeta(
    'leaseExpiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> leaseExpiresAt =
      GeneratedColumn<DateTime>(
        'lease_expires_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    accountKey,
    aggregateId,
    operationType,
    payloadJson,
    baseRevision,
    status,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseExpiresAt,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
        _aggregateIdMeta,
        aggregateId.isAcceptableOrUnknown(
          data['aggregate_id']!,
          _aggregateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_expires_at')) {
      context.handle(
        _leaseExpiresAtMeta,
        leaseExpiresAt.isAcceptableOrUnknown(
          data['lease_expires_at']!,
          _leaseExpiresAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountKey, aggregateId},
  ];
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_revision'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_expires_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String operationId;
  final String accountKey;
  final String aggregateId;
  final String operationType;
  final String payloadJson;
  final String? baseRevision;
  final String status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  final String? lastError;
  final DateTime createdAt;
  const SyncOutboxData({
    required this.operationId,
    required this.accountKey,
    required this.aggregateId,
    required this.operationType,
    required this.payloadJson,
    this.baseRevision,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.leaseOwner,
    this.leaseExpiresAt,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['account_key'] = Variable<String>(accountKey);
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['operation_type'] = Variable<String>(operationType);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || baseRevision != null) {
      map['base_revision'] = Variable<String>(baseRevision);
    }
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseExpiresAt != null) {
      map['lease_expires_at'] = Variable<DateTime>(leaseExpiresAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      operationId: Value(operationId),
      accountKey: Value(accountKey),
      aggregateId: Value(aggregateId),
      operationType: Value(operationType),
      payloadJson: Value(payloadJson),
      baseRevision: baseRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(baseRevision),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseExpiresAt: leaseExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseExpiresAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      operationId: serializer.fromJson<String>(json['operationId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      baseRevision: serializer.fromJson<String?>(json['baseRevision']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseExpiresAt: serializer.fromJson<DateTime?>(json['leaseExpiresAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'accountKey': serializer.toJson<String>(accountKey),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'operationType': serializer.toJson<String>(operationType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'baseRevision': serializer.toJson<String?>(baseRevision),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseExpiresAt': serializer.toJson<DateTime?>(leaseExpiresAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncOutboxData copyWith({
    String? operationId,
    String? accountKey,
    String? aggregateId,
    String? operationType,
    String? payloadJson,
    Value<String?> baseRevision = const Value.absent(),
    String? status,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> leaseOwner = const Value.absent(),
    Value<DateTime?> leaseExpiresAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => SyncOutboxData(
    operationId: operationId ?? this.operationId,
    accountKey: accountKey ?? this.accountKey,
    aggregateId: aggregateId ?? this.aggregateId,
    operationType: operationType ?? this.operationType,
    payloadJson: payloadJson ?? this.payloadJson,
    baseRevision: baseRevision.present ? baseRevision.value : this.baseRevision,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseExpiresAt: leaseExpiresAt.present
        ? leaseExpiresAt.value
        : this.leaseExpiresAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseExpiresAt: data.leaseExpiresAt.present
          ? data.leaseExpiresAt.value
          : this.leaseExpiresAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('operationId: $operationId, ')
          ..write('accountKey: $accountKey, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    accountKey,
    aggregateId,
    operationType,
    payloadJson,
    baseRevision,
    status,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseExpiresAt,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.operationId == this.operationId &&
          other.accountKey == this.accountKey &&
          other.aggregateId == this.aggregateId &&
          other.operationType == this.operationType &&
          other.payloadJson == this.payloadJson &&
          other.baseRevision == this.baseRevision &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseExpiresAt == this.leaseExpiresAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> operationId;
  final Value<String> accountKey;
  final Value<String> aggregateId;
  final Value<String> operationType;
  final Value<String> payloadJson;
  final Value<String?> baseRevision;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> leaseOwner;
  final Value<DateTime?> leaseExpiresAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.operationId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String operationId,
    required String accountKey,
    required String aggregateId,
    required String operationType,
    required String payloadJson,
    this.baseRevision = const Value.absent(),
    required String status,
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       accountKey = Value(accountKey),
       aggregateId = Value(aggregateId),
       operationType = Value(operationType),
       payloadJson = Value(payloadJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? operationId,
    Expression<String>? accountKey,
    Expression<String>? aggregateId,
    Expression<String>? operationType,
    Expression<String>? payloadJson,
    Expression<String>? baseRevision,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? leaseOwner,
    Expression<DateTime>? leaseExpiresAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (accountKey != null) 'account_key': accountKey,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (operationType != null) 'operation_type': operationType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseExpiresAt != null) 'lease_expires_at': leaseExpiresAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? operationId,
    Value<String>? accountKey,
    Value<String>? aggregateId,
    Value<String>? operationType,
    Value<String>? payloadJson,
    Value<String?>? baseRevision,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? leaseOwner,
    Value<DateTime?>? leaseExpiresAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      operationId: operationId ?? this.operationId,
      accountKey: accountKey ?? this.accountKey,
      aggregateId: aggregateId ?? this.aggregateId,
      operationType: operationType ?? this.operationType,
      payloadJson: payloadJson ?? this.payloadJson,
      baseRevision: baseRevision ?? this.baseRevision,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<String>(baseRevision.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseExpiresAt.present) {
      map['lease_expires_at'] = Variable<DateTime>(leaseExpiresAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('operationId: $operationId, ')
          ..write('accountKey: $accountKey, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [accountKey, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String accountKey;
  final String? cursor;
  const SyncMetadataData({required this.accountKey, this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      accountKey: Value(accountKey),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
    );
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      cursor: serializer.fromJson<String?>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'cursor': serializer.toJson<String?>(cursor),
    };
  }

  SyncMetadataData copyWith({
    String? accountKey,
    Value<String?> cursor = const Value.absent(),
  }) => SyncMetadataData(
    accountKey: accountKey ?? this.accountKey,
    cursor: cursor.present ? cursor.value : this.cursor,
  );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('accountKey: $accountKey, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountKey, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.accountKey == this.accountKey &&
          other.cursor == this.cursor);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> accountKey;
  final Value<String?> cursor;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.accountKey = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String accountKey,
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? accountKey,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? accountKey,
    Value<String?>? cursor,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      accountKey: accountKey ?? this.accountKey,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDocumentJsonMeta = const VerificationMeta(
    'localDocumentJson',
  );
  @override
  late final GeneratedColumn<String> localDocumentJson =
      GeneratedColumn<String>(
        'local_document_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _remoteDocumentJsonMeta =
      const VerificationMeta('remoteDocumentJson');
  @override
  late final GeneratedColumn<String> remoteDocumentJson =
      GeneratedColumn<String>(
        'remote_document_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<String> remoteRevision = GeneratedColumn<String>(
    'remote_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    localId,
    localDocumentJson,
    remoteDocumentJson,
    remoteRevision,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('local_document_json')) {
      context.handle(
        _localDocumentJsonMeta,
        localDocumentJson.isAcceptableOrUnknown(
          data['local_document_json']!,
          _localDocumentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localDocumentJsonMeta);
    }
    if (data.containsKey('remote_document_json')) {
      context.handle(
        _remoteDocumentJsonMeta,
        remoteDocumentJson.isAcceptableOrUnknown(
          data['remote_document_json']!,
          _remoteDocumentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteDocumentJsonMeta);
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteRevisionMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, localId};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      localDocumentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_document_json'],
      )!,
      remoteDocumentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_document_json'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_revision'],
      )!,
      detectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}detected_at'],
      )!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final String accountKey;
  final String localId;
  final String localDocumentJson;
  final String remoteDocumentJson;
  final String remoteRevision;
  final DateTime detectedAt;
  const SyncConflictRow({
    required this.accountKey,
    required this.localId,
    required this.localDocumentJson,
    required this.remoteDocumentJson,
    required this.remoteRevision,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['local_id'] = Variable<String>(localId);
    map['local_document_json'] = Variable<String>(localDocumentJson);
    map['remote_document_json'] = Variable<String>(remoteDocumentJson);
    map['remote_revision'] = Variable<String>(remoteRevision);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      accountKey: Value(accountKey),
      localId: Value(localId),
      localDocumentJson: Value(localDocumentJson),
      remoteDocumentJson: Value(remoteDocumentJson),
      remoteRevision: Value(remoteRevision),
      detectedAt: Value(detectedAt),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      localId: serializer.fromJson<String>(json['localId']),
      localDocumentJson: serializer.fromJson<String>(json['localDocumentJson']),
      remoteDocumentJson: serializer.fromJson<String>(
        json['remoteDocumentJson'],
      ),
      remoteRevision: serializer.fromJson<String>(json['remoteRevision']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'localId': serializer.toJson<String>(localId),
      'localDocumentJson': serializer.toJson<String>(localDocumentJson),
      'remoteDocumentJson': serializer.toJson<String>(remoteDocumentJson),
      'remoteRevision': serializer.toJson<String>(remoteRevision),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  SyncConflictRow copyWith({
    String? accountKey,
    String? localId,
    String? localDocumentJson,
    String? remoteDocumentJson,
    String? remoteRevision,
    DateTime? detectedAt,
  }) => SyncConflictRow(
    accountKey: accountKey ?? this.accountKey,
    localId: localId ?? this.localId,
    localDocumentJson: localDocumentJson ?? this.localDocumentJson,
    remoteDocumentJson: remoteDocumentJson ?? this.remoteDocumentJson,
    remoteRevision: remoteRevision ?? this.remoteRevision,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  SyncConflictRow copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      localId: data.localId.present ? data.localId.value : this.localId,
      localDocumentJson: data.localDocumentJson.present
          ? data.localDocumentJson.value
          : this.localDocumentJson,
      remoteDocumentJson: data.remoteDocumentJson.present
          ? data.remoteDocumentJson.value
          : this.remoteDocumentJson,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('accountKey: $accountKey, ')
          ..write('localId: $localId, ')
          ..write('localDocumentJson: $localDocumentJson, ')
          ..write('remoteDocumentJson: $remoteDocumentJson, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountKey,
    localId,
    localDocumentJson,
    remoteDocumentJson,
    remoteRevision,
    detectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.accountKey == this.accountKey &&
          other.localId == this.localId &&
          other.localDocumentJson == this.localDocumentJson &&
          other.remoteDocumentJson == this.remoteDocumentJson &&
          other.remoteRevision == this.remoteRevision &&
          other.detectedAt == this.detectedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<String> accountKey;
  final Value<String> localId;
  final Value<String> localDocumentJson;
  final Value<String> remoteDocumentJson;
  final Value<String> remoteRevision;
  final Value<DateTime> detectedAt;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.accountKey = const Value.absent(),
    this.localId = const Value.absent(),
    this.localDocumentJson = const Value.absent(),
    this.remoteDocumentJson = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String accountKey,
    required String localId,
    required String localDocumentJson,
    required String remoteDocumentJson,
    required String remoteRevision,
    required DateTime detectedAt,
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       localId = Value(localId),
       localDocumentJson = Value(localDocumentJson),
       remoteDocumentJson = Value(remoteDocumentJson),
       remoteRevision = Value(remoteRevision),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflictRow> custom({
    Expression<String>? accountKey,
    Expression<String>? localId,
    Expression<String>? localDocumentJson,
    Expression<String>? remoteDocumentJson,
    Expression<String>? remoteRevision,
    Expression<DateTime>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (localId != null) 'local_id': localId,
      if (localDocumentJson != null) 'local_document_json': localDocumentJson,
      if (remoteDocumentJson != null)
        'remote_document_json': remoteDocumentJson,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? localId,
    Value<String>? localDocumentJson,
    Value<String>? remoteDocumentJson,
    Value<String>? remoteRevision,
    Value<DateTime>? detectedAt,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      accountKey: accountKey ?? this.accountKey,
      localId: localId ?? this.localId,
      localDocumentJson: localDocumentJson ?? this.localDocumentJson,
      remoteDocumentJson: remoteDocumentJson ?? this.remoteDocumentJson,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      detectedAt: detectedAt ?? this.detectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (localDocumentJson.present) {
      map['local_document_json'] = Variable<String>(localDocumentJson.value);
    }
    if (remoteDocumentJson.present) {
      map['remote_document_json'] = Variable<String>(remoteDocumentJson.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<String>(remoteRevision.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('localId: $localId, ')
          ..write('localDocumentJson: $localDocumentJson, ')
          ..write('remoteDocumentJson: $remoteDocumentJson, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotesDatabase extends GeneratedDatabase {
  _$NotesDatabase(QueryExecutor e) : super(e);
  $NotesDatabaseManager get managers => $NotesDatabaseManager(this);
  late final $LocalDocumentsTable localDocuments = $LocalDocumentsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localDocuments,
    syncOutbox,
    syncMetadata,
    syncConflicts,
  ];
}

typedef $$LocalDocumentsTableCreateCompanionBuilder =
    LocalDocumentsCompanion Function({
      required String localId,
      Value<int?> remoteId,
      required String accountKey,
      required String documentJson,
      required DateTime localUpdatedAt,
      Value<String?> serverRevision,
      Value<String?> baseServerRevision,
      required String syncState,
      Value<bool> deletedLocally,
      Value<int> rowid,
    });
typedef $$LocalDocumentsTableUpdateCompanionBuilder =
    LocalDocumentsCompanion Function({
      Value<String> localId,
      Value<int?> remoteId,
      Value<String> accountKey,
      Value<String> documentJson,
      Value<DateTime> localUpdatedAt,
      Value<String?> serverRevision,
      Value<String?> baseServerRevision,
      Value<String> syncState,
      Value<bool> deletedLocally,
      Value<int> rowid,
    });

class $$LocalDocumentsTableFilterComposer
    extends Composer<_$NotesDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseServerRevision => $composableBuilder(
    column: $table.baseServerRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deletedLocally => $composableBuilder(
    column: $table.deletedLocally,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDocumentsTableOrderingComposer
    extends Composer<_$NotesDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseServerRevision => $composableBuilder(
    column: $table.baseServerRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deletedLocally => $composableBuilder(
    column: $table.deletedLocally,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDocumentsTableAnnotationComposer
    extends Composer<_$NotesDatabase, $LocalDocumentsTable> {
  $$LocalDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseServerRevision => $composableBuilder(
    column: $table.baseServerRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<bool> get deletedLocally => $composableBuilder(
    column: $table.deletedLocally,
    builder: (column) => column,
  );
}

class $$LocalDocumentsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalDocumentsTable,
          LocalDocumentRow,
          $$LocalDocumentsTableFilterComposer,
          $$LocalDocumentsTableOrderingComposer,
          $$LocalDocumentsTableAnnotationComposer,
          $$LocalDocumentsTableCreateCompanionBuilder,
          $$LocalDocumentsTableUpdateCompanionBuilder,
          (
            LocalDocumentRow,
            BaseReferences<
              _$NotesDatabase,
              $LocalDocumentsTable,
              LocalDocumentRow
            >,
          ),
          LocalDocumentRow,
          PrefetchHooks Function()
        > {
  $$LocalDocumentsTableTableManager(
    _$NotesDatabase db,
    $LocalDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<int?> remoteId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> documentJson = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<String?> serverRevision = const Value.absent(),
                Value<String?> baseServerRevision = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> deletedLocally = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDocumentsCompanion(
                localId: localId,
                remoteId: remoteId,
                accountKey: accountKey,
                documentJson: documentJson,
                localUpdatedAt: localUpdatedAt,
                serverRevision: serverRevision,
                baseServerRevision: baseServerRevision,
                syncState: syncState,
                deletedLocally: deletedLocally,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<int?> remoteId = const Value.absent(),
                required String accountKey,
                required String documentJson,
                required DateTime localUpdatedAt,
                Value<String?> serverRevision = const Value.absent(),
                Value<String?> baseServerRevision = const Value.absent(),
                required String syncState,
                Value<bool> deletedLocally = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDocumentsCompanion.insert(
                localId: localId,
                remoteId: remoteId,
                accountKey: accountKey,
                documentJson: documentJson,
                localUpdatedAt: localUpdatedAt,
                serverRevision: serverRevision,
                baseServerRevision: baseServerRevision,
                syncState: syncState,
                deletedLocally: deletedLocally,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalDocumentsTable,
      LocalDocumentRow,
      $$LocalDocumentsTableFilterComposer,
      $$LocalDocumentsTableOrderingComposer,
      $$LocalDocumentsTableAnnotationComposer,
      $$LocalDocumentsTableCreateCompanionBuilder,
      $$LocalDocumentsTableUpdateCompanionBuilder,
      (
        LocalDocumentRow,
        BaseReferences<_$NotesDatabase, $LocalDocumentsTable, LocalDocumentRow>,
      ),
      LocalDocumentRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String operationId,
      required String accountKey,
      required String aggregateId,
      required String operationType,
      required String payloadJson,
      Value<String?> baseRevision,
      required String status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> operationId,
      Value<String> accountKey,
      Value<String> aggregateId,
      Value<String> operationType,
      Value<String> payloadJson,
      Value<String?> baseRevision,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$NotesDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$NotesDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$NotesDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseExpiresAt => $composableBuilder(
    column: $table.leaseExpiresAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$NotesDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$NotesDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> aggregateId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> baseRevision = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                operationId: operationId,
                accountKey: accountKey,
                aggregateId: aggregateId,
                operationType: operationType,
                payloadJson: payloadJson,
                baseRevision: baseRevision,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String accountKey,
                required String aggregateId,
                required String operationType,
                required String payloadJson,
                Value<String?> baseRevision = const Value.absent(),
                required String status,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                operationId: operationId,
                accountKey: accountKey,
                aggregateId: aggregateId,
                operationType: operationType,
                payloadJson: payloadJson,
                baseRevision: baseRevision,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$NotesDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String accountKey,
      Value<String?> cursor,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> accountKey,
      Value<String?> cursor,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$NotesDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$NotesDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$NotesDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<
              _$NotesDatabase,
              $SyncMetadataTable,
              SyncMetadataData
            >,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$NotesDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(
                accountKey: accountKey,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                Value<String?> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                accountKey: accountKey,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$NotesDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String accountKey,
      required String localId,
      required String localDocumentJson,
      required String remoteDocumentJson,
      required String remoteRevision,
      required DateTime detectedAt,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> accountKey,
      Value<String> localId,
      Value<String> localDocumentJson,
      Value<String> remoteDocumentJson,
      Value<String> remoteRevision,
      Value<DateTime> detectedAt,
      Value<int> rowid,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$NotesDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDocumentJson => $composableBuilder(
    column: $table.localDocumentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteDocumentJson => $composableBuilder(
    column: $table.remoteDocumentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$NotesDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDocumentJson => $composableBuilder(
    column: $table.localDocumentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteDocumentJson => $composableBuilder(
    column: $table.remoteDocumentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$NotesDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get localDocumentJson => $composableBuilder(
    column: $table.localDocumentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteDocumentJson => $composableBuilder(
    column: $table.remoteDocumentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $SyncConflictsTable,
          SyncConflictRow,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<
              _$NotesDatabase,
              $SyncConflictsTable,
              SyncConflictRow
            >,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(
    _$NotesDatabase db,
    $SyncConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> localId = const Value.absent(),
                Value<String> localDocumentJson = const Value.absent(),
                Value<String> remoteDocumentJson = const Value.absent(),
                Value<String> remoteRevision = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                accountKey: accountKey,
                localId: localId,
                localDocumentJson: localDocumentJson,
                remoteDocumentJson: remoteDocumentJson,
                remoteRevision: remoteRevision,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required String localId,
                required String localDocumentJson,
                required String remoteDocumentJson,
                required String remoteRevision,
                required DateTime detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                accountKey: accountKey,
                localId: localId,
                localDocumentJson: localDocumentJson,
                remoteDocumentJson: remoteDocumentJson,
                remoteRevision: remoteRevision,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $SyncConflictsTable,
      SyncConflictRow,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<_$NotesDatabase, $SyncConflictsTable, SyncConflictRow>,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;

class $NotesDatabaseManager {
  final _$NotesDatabase _db;
  $NotesDatabaseManager(this._db);
  $$LocalDocumentsTableTableManager get localDocuments =>
      $$LocalDocumentsTableTableManager(_db, _db.localDocuments);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
}
