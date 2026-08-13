// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_offline_tables_test.dart';

// ignore_for_file: type=lint
class $TestExpensesTable extends TestExpenses
    with TableInfo<$TestExpensesTable, TestExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestExpensesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountKey, localId, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestExpense> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, localId};
  @override
  TestExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestExpense(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
    );
  }

  @override
  $TestExpensesTable createAlias(String alias) {
    return $TestExpensesTable(attachedDatabase, alias);
  }
}

class TestExpense extends DataClass implements Insertable<TestExpense> {
  final String accountKey;
  final String localId;
  final String description;
  const TestExpense({
    required this.accountKey,
    required this.localId,
    required this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['local_id'] = Variable<String>(localId);
    map['description'] = Variable<String>(description);
    return map;
  }

  TestExpensesCompanion toCompanion(bool nullToAbsent) {
    return TestExpensesCompanion(
      accountKey: Value(accountKey),
      localId: Value(localId),
      description: Value(description),
    );
  }

  factory TestExpense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestExpense(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      localId: serializer.fromJson<String>(json['localId']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'localId': serializer.toJson<String>(localId),
      'description': serializer.toJson<String>(description),
    };
  }

  TestExpense copyWith({
    String? accountKey,
    String? localId,
    String? description,
  }) => TestExpense(
    accountKey: accountKey ?? this.accountKey,
    localId: localId ?? this.localId,
    description: description ?? this.description,
  );
  TestExpense copyWithCompanion(TestExpensesCompanion data) {
    return TestExpense(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      localId: data.localId.present ? data.localId.value : this.localId,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestExpense(')
          ..write('accountKey: $accountKey, ')
          ..write('localId: $localId, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountKey, localId, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestExpense &&
          other.accountKey == this.accountKey &&
          other.localId == this.localId &&
          other.description == this.description);
}

class TestExpensesCompanion extends UpdateCompanion<TestExpense> {
  final Value<String> accountKey;
  final Value<String> localId;
  final Value<String> description;
  final Value<int> rowid;
  const TestExpensesCompanion({
    this.accountKey = const Value.absent(),
    this.localId = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestExpensesCompanion.insert({
    required String accountKey,
    required String localId,
    required String description,
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       localId = Value(localId),
       description = Value(description);
  static Insertable<TestExpense> custom({
    Expression<String>? accountKey,
    Expression<String>? localId,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (localId != null) 'local_id': localId,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestExpensesCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? localId,
    Value<String>? description,
    Value<int>? rowid,
  }) {
    return TestExpensesCompanion(
      accountKey: accountKey ?? this.accountKey,
      localId: localId ?? this.localId,
      description: description ?? this.description,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestExpensesCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('localId: $localId, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineOutboxEntriesTable extends OfflineOutboxEntries
    with TableInfo<$OfflineOutboxEntriesTable, OfflineOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineOutboxEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
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
  static const VerificationMeta _operationGroupMeta = const VerificationMeta(
    'operationGroup',
  );
  @override
  late final GeneratedColumn<String> operationGroup = GeneratedColumn<String>(
    'operation_group',
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
    collection,
    aggregateId,
    remoteId,
    operationType,
    payloadJson,
    baseRevision,
    status,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseExpiresAt,
    lastError,
    operationGroup,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineOutboxEntry> instance, {
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
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
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
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
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
    if (data.containsKey('operation_group')) {
      context.handle(
        _operationGroupMeta,
        operationGroup.isAcceptableOrUnknown(
          data['operation_group']!,
          _operationGroupMeta,
        ),
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
    {accountKey, collection, aggregateId},
  ];
  @override
  OfflineOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineOutboxEntry(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      ),
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
      operationGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_group'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OfflineOutboxEntriesTable createAlias(String alias) {
    return $OfflineOutboxEntriesTable(attachedDatabase, alias);
  }
}

class OfflineOutboxEntry extends DataClass
    implements Insertable<OfflineOutboxEntry> {
  final String operationId;
  final String accountKey;
  final String collection;
  final String aggregateId;
  final int? remoteId;
  final String operationType;
  final String payloadJson;
  final String? baseRevision;
  final String status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? leaseOwner;
  final DateTime? leaseExpiresAt;
  final String? lastError;
  final String? operationGroup;
  final DateTime createdAt;
  const OfflineOutboxEntry({
    required this.operationId,
    required this.accountKey,
    required this.collection,
    required this.aggregateId,
    this.remoteId,
    required this.operationType,
    required this.payloadJson,
    this.baseRevision,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.leaseOwner,
    this.leaseExpiresAt,
    this.lastError,
    this.operationGroup,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['account_key'] = Variable<String>(accountKey);
    map['collection'] = Variable<String>(collection);
    map['aggregate_id'] = Variable<String>(aggregateId);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
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
    if (!nullToAbsent || operationGroup != null) {
      map['operation_group'] = Variable<String>(operationGroup);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OfflineOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OfflineOutboxEntriesCompanion(
      operationId: Value(operationId),
      accountKey: Value(accountKey),
      collection: Value(collection),
      aggregateId: Value(aggregateId),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
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
      operationGroup: operationGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(operationGroup),
      createdAt: Value(createdAt),
    );
  }

  factory OfflineOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineOutboxEntry(
      operationId: serializer.fromJson<String>(json['operationId']),
      accountKey: serializer.fromJson<String>(json['accountKey']),
      collection: serializer.fromJson<String>(json['collection']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      baseRevision: serializer.fromJson<String?>(json['baseRevision']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseExpiresAt: serializer.fromJson<DateTime?>(json['leaseExpiresAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      operationGroup: serializer.fromJson<String?>(json['operationGroup']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'accountKey': serializer.toJson<String>(accountKey),
      'collection': serializer.toJson<String>(collection),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'remoteId': serializer.toJson<int?>(remoteId),
      'operationType': serializer.toJson<String>(operationType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'baseRevision': serializer.toJson<String?>(baseRevision),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseExpiresAt': serializer.toJson<DateTime?>(leaseExpiresAt),
      'lastError': serializer.toJson<String?>(lastError),
      'operationGroup': serializer.toJson<String?>(operationGroup),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OfflineOutboxEntry copyWith({
    String? operationId,
    String? accountKey,
    String? collection,
    String? aggregateId,
    Value<int?> remoteId = const Value.absent(),
    String? operationType,
    String? payloadJson,
    Value<String?> baseRevision = const Value.absent(),
    String? status,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> leaseOwner = const Value.absent(),
    Value<DateTime?> leaseExpiresAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> operationGroup = const Value.absent(),
    DateTime? createdAt,
  }) => OfflineOutboxEntry(
    operationId: operationId ?? this.operationId,
    accountKey: accountKey ?? this.accountKey,
    collection: collection ?? this.collection,
    aggregateId: aggregateId ?? this.aggregateId,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
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
    operationGroup: operationGroup.present
        ? operationGroup.value
        : this.operationGroup,
    createdAt: createdAt ?? this.createdAt,
  );
  OfflineOutboxEntry copyWithCompanion(OfflineOutboxEntriesCompanion data) {
    return OfflineOutboxEntry(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
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
      operationGroup: data.operationGroup.present
          ? data.operationGroup.value
          : this.operationGroup,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineOutboxEntry(')
          ..write('operationId: $operationId, ')
          ..write('accountKey: $accountKey, ')
          ..write('collection: $collection, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('remoteId: $remoteId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt, ')
          ..write('lastError: $lastError, ')
          ..write('operationGroup: $operationGroup, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    accountKey,
    collection,
    aggregateId,
    remoteId,
    operationType,
    payloadJson,
    baseRevision,
    status,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseExpiresAt,
    lastError,
    operationGroup,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineOutboxEntry &&
          other.operationId == this.operationId &&
          other.accountKey == this.accountKey &&
          other.collection == this.collection &&
          other.aggregateId == this.aggregateId &&
          other.remoteId == this.remoteId &&
          other.operationType == this.operationType &&
          other.payloadJson == this.payloadJson &&
          other.baseRevision == this.baseRevision &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseExpiresAt == this.leaseExpiresAt &&
          other.lastError == this.lastError &&
          other.operationGroup == this.operationGroup &&
          other.createdAt == this.createdAt);
}

class OfflineOutboxEntriesCompanion
    extends UpdateCompanion<OfflineOutboxEntry> {
  final Value<String> operationId;
  final Value<String> accountKey;
  final Value<String> collection;
  final Value<String> aggregateId;
  final Value<int?> remoteId;
  final Value<String> operationType;
  final Value<String> payloadJson;
  final Value<String?> baseRevision;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> leaseOwner;
  final Value<DateTime?> leaseExpiresAt;
  final Value<String?> lastError;
  final Value<String?> operationGroup;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OfflineOutboxEntriesCompanion({
    this.operationId = const Value.absent(),
    this.accountKey = const Value.absent(),
    this.collection = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.operationGroup = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineOutboxEntriesCompanion.insert({
    required String operationId,
    required String accountKey,
    required String collection,
    required String aggregateId,
    this.remoteId = const Value.absent(),
    required String operationType,
    required String payloadJson,
    this.baseRevision = const Value.absent(),
    required String status,
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseExpiresAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.operationGroup = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       accountKey = Value(accountKey),
       collection = Value(collection),
       aggregateId = Value(aggregateId),
       operationType = Value(operationType),
       payloadJson = Value(payloadJson),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<OfflineOutboxEntry> custom({
    Expression<String>? operationId,
    Expression<String>? accountKey,
    Expression<String>? collection,
    Expression<String>? aggregateId,
    Expression<int>? remoteId,
    Expression<String>? operationType,
    Expression<String>? payloadJson,
    Expression<String>? baseRevision,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? leaseOwner,
    Expression<DateTime>? leaseExpiresAt,
    Expression<String>? lastError,
    Expression<String>? operationGroup,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (accountKey != null) 'account_key': accountKey,
      if (collection != null) 'collection': collection,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (remoteId != null) 'remote_id': remoteId,
      if (operationType != null) 'operation_type': operationType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseExpiresAt != null) 'lease_expires_at': leaseExpiresAt,
      if (lastError != null) 'last_error': lastError,
      if (operationGroup != null) 'operation_group': operationGroup,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineOutboxEntriesCompanion copyWith({
    Value<String>? operationId,
    Value<String>? accountKey,
    Value<String>? collection,
    Value<String>? aggregateId,
    Value<int?>? remoteId,
    Value<String>? operationType,
    Value<String>? payloadJson,
    Value<String?>? baseRevision,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? leaseOwner,
    Value<DateTime?>? leaseExpiresAt,
    Value<String?>? lastError,
    Value<String?>? operationGroup,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OfflineOutboxEntriesCompanion(
      operationId: operationId ?? this.operationId,
      accountKey: accountKey ?? this.accountKey,
      collection: collection ?? this.collection,
      aggregateId: aggregateId ?? this.aggregateId,
      remoteId: remoteId ?? this.remoteId,
      operationType: operationType ?? this.operationType,
      payloadJson: payloadJson ?? this.payloadJson,
      baseRevision: baseRevision ?? this.baseRevision,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      lastError: lastError ?? this.lastError,
      operationGroup: operationGroup ?? this.operationGroup,
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
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
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
    if (operationGroup.present) {
      map['operation_group'] = Variable<String>(operationGroup.value);
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
    return (StringBuffer('OfflineOutboxEntriesCompanion(')
          ..write('operationId: $operationId, ')
          ..write('accountKey: $accountKey, ')
          ..write('collection: $collection, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('remoteId: $remoteId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseExpiresAt: $leaseExpiresAt, ')
          ..write('lastError: $lastError, ')
          ..write('operationGroup: $operationGroup, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineSyncMetadataEntriesTable extends OfflineSyncMetadataEntries
    with TableInfo<$OfflineSyncMetadataEntriesTable, OfflineSyncMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineSyncMetadataEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _datasetMeta = const VerificationMeta(
    'dataset',
  );
  @override
  late final GeneratedColumn<String> dataset = GeneratedColumn<String>(
    'dataset',
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
  static const VerificationMeta _lastCompletedAtMeta = const VerificationMeta(
    'lastCompletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCompletedAt =
      GeneratedColumn<DateTime>(
        'last_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    dataset,
    cursor,
    lastCompletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineSyncMetadataEntry> instance, {
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
    if (data.containsKey('dataset')) {
      context.handle(
        _datasetMeta,
        dataset.isAcceptableOrUnknown(data['dataset']!, _datasetMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_completed_at')) {
      context.handle(
        _lastCompletedAtMeta,
        lastCompletedAt.isAcceptableOrUnknown(
          data['last_completed_at']!,
          _lastCompletedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, dataset};
  @override
  OfflineSyncMetadataEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineSyncMetadataEntry(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      dataset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      lastCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_completed_at'],
      ),
    );
  }

  @override
  $OfflineSyncMetadataEntriesTable createAlias(String alias) {
    return $OfflineSyncMetadataEntriesTable(attachedDatabase, alias);
  }
}

class OfflineSyncMetadataEntry extends DataClass
    implements Insertable<OfflineSyncMetadataEntry> {
  final String accountKey;
  final String dataset;
  final String? cursor;
  final DateTime? lastCompletedAt;
  const OfflineSyncMetadataEntry({
    required this.accountKey,
    required this.dataset,
    this.cursor,
    this.lastCompletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['dataset'] = Variable<String>(dataset);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || lastCompletedAt != null) {
      map['last_completed_at'] = Variable<DateTime>(lastCompletedAt);
    }
    return map;
  }

  OfflineSyncMetadataEntriesCompanion toCompanion(bool nullToAbsent) {
    return OfflineSyncMetadataEntriesCompanion(
      accountKey: Value(accountKey),
      dataset: Value(dataset),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      lastCompletedAt: lastCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletedAt),
    );
  }

  factory OfflineSyncMetadataEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineSyncMetadataEntry(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      dataset: serializer.fromJson<String>(json['dataset']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      lastCompletedAt: serializer.fromJson<DateTime?>(json['lastCompletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'dataset': serializer.toJson<String>(dataset),
      'cursor': serializer.toJson<String?>(cursor),
      'lastCompletedAt': serializer.toJson<DateTime?>(lastCompletedAt),
    };
  }

  OfflineSyncMetadataEntry copyWith({
    String? accountKey,
    String? dataset,
    Value<String?> cursor = const Value.absent(),
    Value<DateTime?> lastCompletedAt = const Value.absent(),
  }) => OfflineSyncMetadataEntry(
    accountKey: accountKey ?? this.accountKey,
    dataset: dataset ?? this.dataset,
    cursor: cursor.present ? cursor.value : this.cursor,
    lastCompletedAt: lastCompletedAt.present
        ? lastCompletedAt.value
        : this.lastCompletedAt,
  );
  OfflineSyncMetadataEntry copyWithCompanion(
    OfflineSyncMetadataEntriesCompanion data,
  ) {
    return OfflineSyncMetadataEntry(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      dataset: data.dataset.present ? data.dataset.value : this.dataset,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastCompletedAt: data.lastCompletedAt.present
          ? data.lastCompletedAt.value
          : this.lastCompletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSyncMetadataEntry(')
          ..write('accountKey: $accountKey, ')
          ..write('dataset: $dataset, ')
          ..write('cursor: $cursor, ')
          ..write('lastCompletedAt: $lastCompletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountKey, dataset, cursor, lastCompletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineSyncMetadataEntry &&
          other.accountKey == this.accountKey &&
          other.dataset == this.dataset &&
          other.cursor == this.cursor &&
          other.lastCompletedAt == this.lastCompletedAt);
}

class OfflineSyncMetadataEntriesCompanion
    extends UpdateCompanion<OfflineSyncMetadataEntry> {
  final Value<String> accountKey;
  final Value<String> dataset;
  final Value<String?> cursor;
  final Value<DateTime?> lastCompletedAt;
  final Value<int> rowid;
  const OfflineSyncMetadataEntriesCompanion({
    this.accountKey = const Value.absent(),
    this.dataset = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineSyncMetadataEntriesCompanion.insert({
    required String accountKey,
    required String dataset,
    this.cursor = const Value.absent(),
    this.lastCompletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       dataset = Value(dataset);
  static Insertable<OfflineSyncMetadataEntry> custom({
    Expression<String>? accountKey,
    Expression<String>? dataset,
    Expression<String>? cursor,
    Expression<DateTime>? lastCompletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (dataset != null) 'dataset': dataset,
      if (cursor != null) 'cursor': cursor,
      if (lastCompletedAt != null) 'last_completed_at': lastCompletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineSyncMetadataEntriesCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? dataset,
    Value<String?>? cursor,
    Value<DateTime?>? lastCompletedAt,
    Value<int>? rowid,
  }) {
    return OfflineSyncMetadataEntriesCompanion(
      accountKey: accountKey ?? this.accountKey,
      dataset: dataset ?? this.dataset,
      cursor: cursor ?? this.cursor,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (dataset.present) {
      map['dataset'] = Variable<String>(dataset.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (lastCompletedAt.present) {
      map['last_completed_at'] = Variable<DateTime>(lastCompletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSyncMetadataEntriesCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('dataset: $dataset, ')
          ..write('cursor: $cursor, ')
          ..write('lastCompletedAt: $lastCompletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineConflictEntriesTable extends OfflineConflictEntries
    with TableInfo<$OfflineConflictEntriesTable, OfflineConflictEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineConflictEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
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
  static const VerificationMeta _localPayloadJsonMeta = const VerificationMeta(
    'localPayloadJson',
  );
  @override
  late final GeneratedColumn<String> localPayloadJson = GeneratedColumn<String>(
    'local_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remotePayloadJsonMeta = const VerificationMeta(
    'remotePayloadJson',
  );
  @override
  late final GeneratedColumn<String> remotePayloadJson =
      GeneratedColumn<String>(
        'remote_payload_json',
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
    collection,
    aggregateId,
    remoteId,
    localPayloadJson,
    remotePayloadJson,
    remoteRevision,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineConflictEntry> instance, {
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
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
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
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('local_payload_json')) {
      context.handle(
        _localPayloadJsonMeta,
        localPayloadJson.isAcceptableOrUnknown(
          data['local_payload_json']!,
          _localPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localPayloadJsonMeta);
    }
    if (data.containsKey('remote_payload_json')) {
      context.handle(
        _remotePayloadJsonMeta,
        remotePayloadJson.isAcceptableOrUnknown(
          data['remote_payload_json']!,
          _remotePayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remotePayloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {accountKey, collection, aggregateId};
  @override
  OfflineConflictEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineConflictEntry(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      ),
      localPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_payload_json'],
      )!,
      remotePayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_payload_json'],
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
  $OfflineConflictEntriesTable createAlias(String alias) {
    return $OfflineConflictEntriesTable(attachedDatabase, alias);
  }
}

class OfflineConflictEntry extends DataClass
    implements Insertable<OfflineConflictEntry> {
  final String accountKey;
  final String collection;
  final String aggregateId;
  final int? remoteId;
  final String localPayloadJson;
  final String remotePayloadJson;
  final String remoteRevision;
  final DateTime detectedAt;
  const OfflineConflictEntry({
    required this.accountKey,
    required this.collection,
    required this.aggregateId,
    this.remoteId,
    required this.localPayloadJson,
    required this.remotePayloadJson,
    required this.remoteRevision,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['collection'] = Variable<String>(collection);
    map['aggregate_id'] = Variable<String>(aggregateId);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['local_payload_json'] = Variable<String>(localPayloadJson);
    map['remote_payload_json'] = Variable<String>(remotePayloadJson);
    map['remote_revision'] = Variable<String>(remoteRevision);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  OfflineConflictEntriesCompanion toCompanion(bool nullToAbsent) {
    return OfflineConflictEntriesCompanion(
      accountKey: Value(accountKey),
      collection: Value(collection),
      aggregateId: Value(aggregateId),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      localPayloadJson: Value(localPayloadJson),
      remotePayloadJson: Value(remotePayloadJson),
      remoteRevision: Value(remoteRevision),
      detectedAt: Value(detectedAt),
    );
  }

  factory OfflineConflictEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineConflictEntry(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      collection: serializer.fromJson<String>(json['collection']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      localPayloadJson: serializer.fromJson<String>(json['localPayloadJson']),
      remotePayloadJson: serializer.fromJson<String>(json['remotePayloadJson']),
      remoteRevision: serializer.fromJson<String>(json['remoteRevision']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'collection': serializer.toJson<String>(collection),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'remoteId': serializer.toJson<int?>(remoteId),
      'localPayloadJson': serializer.toJson<String>(localPayloadJson),
      'remotePayloadJson': serializer.toJson<String>(remotePayloadJson),
      'remoteRevision': serializer.toJson<String>(remoteRevision),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  OfflineConflictEntry copyWith({
    String? accountKey,
    String? collection,
    String? aggregateId,
    Value<int?> remoteId = const Value.absent(),
    String? localPayloadJson,
    String? remotePayloadJson,
    String? remoteRevision,
    DateTime? detectedAt,
  }) => OfflineConflictEntry(
    accountKey: accountKey ?? this.accountKey,
    collection: collection ?? this.collection,
    aggregateId: aggregateId ?? this.aggregateId,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    localPayloadJson: localPayloadJson ?? this.localPayloadJson,
    remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
    remoteRevision: remoteRevision ?? this.remoteRevision,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  OfflineConflictEntry copyWithCompanion(OfflineConflictEntriesCompanion data) {
    return OfflineConflictEntry(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      localPayloadJson: data.localPayloadJson.present
          ? data.localPayloadJson.value
          : this.localPayloadJson,
      remotePayloadJson: data.remotePayloadJson.present
          ? data.remotePayloadJson.value
          : this.remotePayloadJson,
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
    return (StringBuffer('OfflineConflictEntry(')
          ..write('accountKey: $accountKey, ')
          ..write('collection: $collection, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('remoteId: $remoteId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountKey,
    collection,
    aggregateId,
    remoteId,
    localPayloadJson,
    remotePayloadJson,
    remoteRevision,
    detectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineConflictEntry &&
          other.accountKey == this.accountKey &&
          other.collection == this.collection &&
          other.aggregateId == this.aggregateId &&
          other.remoteId == this.remoteId &&
          other.localPayloadJson == this.localPayloadJson &&
          other.remotePayloadJson == this.remotePayloadJson &&
          other.remoteRevision == this.remoteRevision &&
          other.detectedAt == this.detectedAt);
}

class OfflineConflictEntriesCompanion
    extends UpdateCompanion<OfflineConflictEntry> {
  final Value<String> accountKey;
  final Value<String> collection;
  final Value<String> aggregateId;
  final Value<int?> remoteId;
  final Value<String> localPayloadJson;
  final Value<String> remotePayloadJson;
  final Value<String> remoteRevision;
  final Value<DateTime> detectedAt;
  final Value<int> rowid;
  const OfflineConflictEntriesCompanion({
    this.accountKey = const Value.absent(),
    this.collection = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.remotePayloadJson = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineConflictEntriesCompanion.insert({
    required String accountKey,
    required String collection,
    required String aggregateId,
    this.remoteId = const Value.absent(),
    required String localPayloadJson,
    required String remotePayloadJson,
    required String remoteRevision,
    required DateTime detectedAt,
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       collection = Value(collection),
       aggregateId = Value(aggregateId),
       localPayloadJson = Value(localPayloadJson),
       remotePayloadJson = Value(remotePayloadJson),
       remoteRevision = Value(remoteRevision),
       detectedAt = Value(detectedAt);
  static Insertable<OfflineConflictEntry> custom({
    Expression<String>? accountKey,
    Expression<String>? collection,
    Expression<String>? aggregateId,
    Expression<int>? remoteId,
    Expression<String>? localPayloadJson,
    Expression<String>? remotePayloadJson,
    Expression<String>? remoteRevision,
    Expression<DateTime>? detectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (collection != null) 'collection': collection,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (remoteId != null) 'remote_id': remoteId,
      if (localPayloadJson != null) 'local_payload_json': localPayloadJson,
      if (remotePayloadJson != null) 'remote_payload_json': remotePayloadJson,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineConflictEntriesCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? collection,
    Value<String>? aggregateId,
    Value<int?>? remoteId,
    Value<String>? localPayloadJson,
    Value<String>? remotePayloadJson,
    Value<String>? remoteRevision,
    Value<DateTime>? detectedAt,
    Value<int>? rowid,
  }) {
    return OfflineConflictEntriesCompanion(
      accountKey: accountKey ?? this.accountKey,
      collection: collection ?? this.collection,
      aggregateId: aggregateId ?? this.aggregateId,
      remoteId: remoteId ?? this.remoteId,
      localPayloadJson: localPayloadJson ?? this.localPayloadJson,
      remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
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
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (localPayloadJson.present) {
      map['local_payload_json'] = Variable<String>(localPayloadJson.value);
    }
    if (remotePayloadJson.present) {
      map['remote_payload_json'] = Variable<String>(remotePayloadJson.value);
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
    return (StringBuffer('OfflineConflictEntriesCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('collection: $collection, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('remoteId: $remoteId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TestApplicationDatabase extends GeneratedDatabase {
  _$TestApplicationDatabase(QueryExecutor e) : super(e);
  $TestApplicationDatabaseManager get managers =>
      $TestApplicationDatabaseManager(this);
  late final $TestExpensesTable testExpenses = $TestExpensesTable(this);
  late final $OfflineOutboxEntriesTable offlineOutboxEntries =
      $OfflineOutboxEntriesTable(this);
  late final $OfflineSyncMetadataEntriesTable offlineSyncMetadataEntries =
      $OfflineSyncMetadataEntriesTable(this);
  late final $OfflineConflictEntriesTable offlineConflictEntries =
      $OfflineConflictEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    testExpenses,
    offlineOutboxEntries,
    offlineSyncMetadataEntries,
    offlineConflictEntries,
  ];
}

typedef $$TestExpensesTableCreateCompanionBuilder =
    TestExpensesCompanion Function({
      required String accountKey,
      required String localId,
      required String description,
      Value<int> rowid,
    });
typedef $$TestExpensesTableUpdateCompanionBuilder =
    TestExpensesCompanion Function({
      Value<String> accountKey,
      Value<String> localId,
      Value<String> description,
      Value<int> rowid,
    });

class $$TestExpensesTableFilterComposer
    extends Composer<_$TestApplicationDatabase, $TestExpensesTable> {
  $$TestExpensesTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TestExpensesTableOrderingComposer
    extends Composer<_$TestApplicationDatabase, $TestExpensesTable> {
  $$TestExpensesTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TestExpensesTableAnnotationComposer
    extends Composer<_$TestApplicationDatabase, $TestExpensesTable> {
  $$TestExpensesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$TestExpensesTableTableManager
    extends
        RootTableManager<
          _$TestApplicationDatabase,
          $TestExpensesTable,
          TestExpense,
          $$TestExpensesTableFilterComposer,
          $$TestExpensesTableOrderingComposer,
          $$TestExpensesTableAnnotationComposer,
          $$TestExpensesTableCreateCompanionBuilder,
          $$TestExpensesTableUpdateCompanionBuilder,
          (
            TestExpense,
            BaseReferences<
              _$TestApplicationDatabase,
              $TestExpensesTable,
              TestExpense
            >,
          ),
          TestExpense,
          PrefetchHooks Function()
        > {
  $$TestExpensesTableTableManager(
    _$TestApplicationDatabase db,
    $TestExpensesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> localId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TestExpensesCompanion(
                accountKey: accountKey,
                localId: localId,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required String localId,
                required String description,
                Value<int> rowid = const Value.absent(),
              }) => TestExpensesCompanion.insert(
                accountKey: accountKey,
                localId: localId,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TestExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$TestApplicationDatabase,
      $TestExpensesTable,
      TestExpense,
      $$TestExpensesTableFilterComposer,
      $$TestExpensesTableOrderingComposer,
      $$TestExpensesTableAnnotationComposer,
      $$TestExpensesTableCreateCompanionBuilder,
      $$TestExpensesTableUpdateCompanionBuilder,
      (
        TestExpense,
        BaseReferences<
          _$TestApplicationDatabase,
          $TestExpensesTable,
          TestExpense
        >,
      ),
      TestExpense,
      PrefetchHooks Function()
    >;
typedef $$OfflineOutboxEntriesTableCreateCompanionBuilder =
    OfflineOutboxEntriesCompanion Function({
      required String operationId,
      required String accountKey,
      required String collection,
      required String aggregateId,
      Value<int?> remoteId,
      required String operationType,
      required String payloadJson,
      Value<String?> baseRevision,
      required String status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<String?> lastError,
      Value<String?> operationGroup,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OfflineOutboxEntriesTableUpdateCompanionBuilder =
    OfflineOutboxEntriesCompanion Function({
      Value<String> operationId,
      Value<String> accountKey,
      Value<String> collection,
      Value<String> aggregateId,
      Value<int?> remoteId,
      Value<String> operationType,
      Value<String> payloadJson,
      Value<String?> baseRevision,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseExpiresAt,
      Value<String?> lastError,
      Value<String?> operationGroup,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OfflineOutboxEntriesTableFilterComposer
    extends Composer<_$TestApplicationDatabase, $OfflineOutboxEntriesTable> {
  $$OfflineOutboxEntriesTableFilterComposer({
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

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
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

  ColumnFilters<String> get operationGroup => $composableBuilder(
    column: $table.operationGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineOutboxEntriesTableOrderingComposer
    extends Composer<_$TestApplicationDatabase, $OfflineOutboxEntriesTable> {
  $$OfflineOutboxEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
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

  ColumnOrderings<String> get operationGroup => $composableBuilder(
    column: $table.operationGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineOutboxEntriesTableAnnotationComposer
    extends Composer<_$TestApplicationDatabase, $OfflineOutboxEntriesTable> {
  $$OfflineOutboxEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

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

  GeneratedColumn<String> get operationGroup => $composableBuilder(
    column: $table.operationGroup,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OfflineOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$TestApplicationDatabase,
          $OfflineOutboxEntriesTable,
          OfflineOutboxEntry,
          $$OfflineOutboxEntriesTableFilterComposer,
          $$OfflineOutboxEntriesTableOrderingComposer,
          $$OfflineOutboxEntriesTableAnnotationComposer,
          $$OfflineOutboxEntriesTableCreateCompanionBuilder,
          $$OfflineOutboxEntriesTableUpdateCompanionBuilder,
          (
            OfflineOutboxEntry,
            BaseReferences<
              _$TestApplicationDatabase,
              $OfflineOutboxEntriesTable,
              OfflineOutboxEntry
            >,
          ),
          OfflineOutboxEntry,
          PrefetchHooks Function()
        > {
  $$OfflineOutboxEntriesTableTableManager(
    _$TestApplicationDatabase db,
    $OfflineOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineOutboxEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> accountKey = const Value.absent(),
                Value<String> collection = const Value.absent(),
                Value<String> aggregateId = const Value.absent(),
                Value<int?> remoteId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> baseRevision = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> operationGroup = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineOutboxEntriesCompanion(
                operationId: operationId,
                accountKey: accountKey,
                collection: collection,
                aggregateId: aggregateId,
                remoteId: remoteId,
                operationType: operationType,
                payloadJson: payloadJson,
                baseRevision: baseRevision,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                lastError: lastError,
                operationGroup: operationGroup,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String accountKey,
                required String collection,
                required String aggregateId,
                Value<int?> remoteId = const Value.absent(),
                required String operationType,
                required String payloadJson,
                Value<String?> baseRevision = const Value.absent(),
                required String status,
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseExpiresAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> operationGroup = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineOutboxEntriesCompanion.insert(
                operationId: operationId,
                accountKey: accountKey,
                collection: collection,
                aggregateId: aggregateId,
                remoteId: remoteId,
                operationType: operationType,
                payloadJson: payloadJson,
                baseRevision: baseRevision,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseExpiresAt: leaseExpiresAt,
                lastError: lastError,
                operationGroup: operationGroup,
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

typedef $$OfflineOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TestApplicationDatabase,
      $OfflineOutboxEntriesTable,
      OfflineOutboxEntry,
      $$OfflineOutboxEntriesTableFilterComposer,
      $$OfflineOutboxEntriesTableOrderingComposer,
      $$OfflineOutboxEntriesTableAnnotationComposer,
      $$OfflineOutboxEntriesTableCreateCompanionBuilder,
      $$OfflineOutboxEntriesTableUpdateCompanionBuilder,
      (
        OfflineOutboxEntry,
        BaseReferences<
          _$TestApplicationDatabase,
          $OfflineOutboxEntriesTable,
          OfflineOutboxEntry
        >,
      ),
      OfflineOutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$OfflineSyncMetadataEntriesTableCreateCompanionBuilder =
    OfflineSyncMetadataEntriesCompanion Function({
      required String accountKey,
      required String dataset,
      Value<String?> cursor,
      Value<DateTime?> lastCompletedAt,
      Value<int> rowid,
    });
typedef $$OfflineSyncMetadataEntriesTableUpdateCompanionBuilder =
    OfflineSyncMetadataEntriesCompanion Function({
      Value<String> accountKey,
      Value<String> dataset,
      Value<String?> cursor,
      Value<DateTime?> lastCompletedAt,
      Value<int> rowid,
    });

class $$OfflineSyncMetadataEntriesTableFilterComposer
    extends
        Composer<_$TestApplicationDatabase, $OfflineSyncMetadataEntriesTable> {
  $$OfflineSyncMetadataEntriesTableFilterComposer({
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

  ColumnFilters<String> get dataset => $composableBuilder(
    column: $table.dataset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineSyncMetadataEntriesTableOrderingComposer
    extends
        Composer<_$TestApplicationDatabase, $OfflineSyncMetadataEntriesTable> {
  $$OfflineSyncMetadataEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get dataset => $composableBuilder(
    column: $table.dataset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineSyncMetadataEntriesTableAnnotationComposer
    extends
        Composer<_$TestApplicationDatabase, $OfflineSyncMetadataEntriesTable> {
  $$OfflineSyncMetadataEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get dataset =>
      $composableBuilder(column: $table.dataset, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCompletedAt => $composableBuilder(
    column: $table.lastCompletedAt,
    builder: (column) => column,
  );
}

class $$OfflineSyncMetadataEntriesTableTableManager
    extends
        RootTableManager<
          _$TestApplicationDatabase,
          $OfflineSyncMetadataEntriesTable,
          OfflineSyncMetadataEntry,
          $$OfflineSyncMetadataEntriesTableFilterComposer,
          $$OfflineSyncMetadataEntriesTableOrderingComposer,
          $$OfflineSyncMetadataEntriesTableAnnotationComposer,
          $$OfflineSyncMetadataEntriesTableCreateCompanionBuilder,
          $$OfflineSyncMetadataEntriesTableUpdateCompanionBuilder,
          (
            OfflineSyncMetadataEntry,
            BaseReferences<
              _$TestApplicationDatabase,
              $OfflineSyncMetadataEntriesTable,
              OfflineSyncMetadataEntry
            >,
          ),
          OfflineSyncMetadataEntry,
          PrefetchHooks Function()
        > {
  $$OfflineSyncMetadataEntriesTableTableManager(
    _$TestApplicationDatabase db,
    $OfflineSyncMetadataEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineSyncMetadataEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineSyncMetadataEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineSyncMetadataEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> dataset = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastCompletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSyncMetadataEntriesCompanion(
                accountKey: accountKey,
                dataset: dataset,
                cursor: cursor,
                lastCompletedAt: lastCompletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required String dataset,
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastCompletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSyncMetadataEntriesCompanion.insert(
                accountKey: accountKey,
                dataset: dataset,
                cursor: cursor,
                lastCompletedAt: lastCompletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineSyncMetadataEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TestApplicationDatabase,
      $OfflineSyncMetadataEntriesTable,
      OfflineSyncMetadataEntry,
      $$OfflineSyncMetadataEntriesTableFilterComposer,
      $$OfflineSyncMetadataEntriesTableOrderingComposer,
      $$OfflineSyncMetadataEntriesTableAnnotationComposer,
      $$OfflineSyncMetadataEntriesTableCreateCompanionBuilder,
      $$OfflineSyncMetadataEntriesTableUpdateCompanionBuilder,
      (
        OfflineSyncMetadataEntry,
        BaseReferences<
          _$TestApplicationDatabase,
          $OfflineSyncMetadataEntriesTable,
          OfflineSyncMetadataEntry
        >,
      ),
      OfflineSyncMetadataEntry,
      PrefetchHooks Function()
    >;
typedef $$OfflineConflictEntriesTableCreateCompanionBuilder =
    OfflineConflictEntriesCompanion Function({
      required String accountKey,
      required String collection,
      required String aggregateId,
      Value<int?> remoteId,
      required String localPayloadJson,
      required String remotePayloadJson,
      required String remoteRevision,
      required DateTime detectedAt,
      Value<int> rowid,
    });
typedef $$OfflineConflictEntriesTableUpdateCompanionBuilder =
    OfflineConflictEntriesCompanion Function({
      Value<String> accountKey,
      Value<String> collection,
      Value<String> aggregateId,
      Value<int?> remoteId,
      Value<String> localPayloadJson,
      Value<String> remotePayloadJson,
      Value<String> remoteRevision,
      Value<DateTime> detectedAt,
      Value<int> rowid,
    });

class $$OfflineConflictEntriesTableFilterComposer
    extends Composer<_$TestApplicationDatabase, $OfflineConflictEntriesTable> {
  $$OfflineConflictEntriesTableFilterComposer({
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

  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
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

class $$OfflineConflictEntriesTableOrderingComposer
    extends Composer<_$TestApplicationDatabase, $OfflineConflictEntriesTable> {
  $$OfflineConflictEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
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

class $$OfflineConflictEntriesTableAnnotationComposer
    extends Composer<_$TestApplicationDatabase, $OfflineConflictEntriesTable> {
  $$OfflineConflictEntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
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

class $$OfflineConflictEntriesTableTableManager
    extends
        RootTableManager<
          _$TestApplicationDatabase,
          $OfflineConflictEntriesTable,
          OfflineConflictEntry,
          $$OfflineConflictEntriesTableFilterComposer,
          $$OfflineConflictEntriesTableOrderingComposer,
          $$OfflineConflictEntriesTableAnnotationComposer,
          $$OfflineConflictEntriesTableCreateCompanionBuilder,
          $$OfflineConflictEntriesTableUpdateCompanionBuilder,
          (
            OfflineConflictEntry,
            BaseReferences<
              _$TestApplicationDatabase,
              $OfflineConflictEntriesTable,
              OfflineConflictEntry
            >,
          ),
          OfflineConflictEntry,
          PrefetchHooks Function()
        > {
  $$OfflineConflictEntriesTableTableManager(
    _$TestApplicationDatabase db,
    $OfflineConflictEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineConflictEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineConflictEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineConflictEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> collection = const Value.absent(),
                Value<String> aggregateId = const Value.absent(),
                Value<int?> remoteId = const Value.absent(),
                Value<String> localPayloadJson = const Value.absent(),
                Value<String> remotePayloadJson = const Value.absent(),
                Value<String> remoteRevision = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineConflictEntriesCompanion(
                accountKey: accountKey,
                collection: collection,
                aggregateId: aggregateId,
                remoteId: remoteId,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
                remoteRevision: remoteRevision,
                detectedAt: detectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required String collection,
                required String aggregateId,
                Value<int?> remoteId = const Value.absent(),
                required String localPayloadJson,
                required String remotePayloadJson,
                required String remoteRevision,
                required DateTime detectedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineConflictEntriesCompanion.insert(
                accountKey: accountKey,
                collection: collection,
                aggregateId: aggregateId,
                remoteId: remoteId,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
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

typedef $$OfflineConflictEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$TestApplicationDatabase,
      $OfflineConflictEntriesTable,
      OfflineConflictEntry,
      $$OfflineConflictEntriesTableFilterComposer,
      $$OfflineConflictEntriesTableOrderingComposer,
      $$OfflineConflictEntriesTableAnnotationComposer,
      $$OfflineConflictEntriesTableCreateCompanionBuilder,
      $$OfflineConflictEntriesTableUpdateCompanionBuilder,
      (
        OfflineConflictEntry,
        BaseReferences<
          _$TestApplicationDatabase,
          $OfflineConflictEntriesTable,
          OfflineConflictEntry
        >,
      ),
      OfflineConflictEntry,
      PrefetchHooks Function()
    >;

class $TestApplicationDatabaseManager {
  final _$TestApplicationDatabase _db;
  $TestApplicationDatabaseManager(this._db);
  $$TestExpensesTableTableManager get testExpenses =>
      $$TestExpensesTableTableManager(_db, _db.testExpenses);
  $$OfflineOutboxEntriesTableTableManager get offlineOutboxEntries =>
      $$OfflineOutboxEntriesTableTableManager(_db, _db.offlineOutboxEntries);
  $$OfflineSyncMetadataEntriesTableTableManager
  get offlineSyncMetadataEntries =>
      $$OfflineSyncMetadataEntriesTableTableManager(
        _db,
        _db.offlineSyncMetadataEntries,
      );
  $$OfflineConflictEntriesTableTableManager get offlineConflictEntries =>
      $$OfflineConflictEntriesTableTableManager(
        _db,
        _db.offlineConflictEntries,
      );
}
