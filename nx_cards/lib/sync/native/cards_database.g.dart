// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cards_database.dart';

// ignore_for_file: type=lint
class $LocalStudyCardsTable extends LocalStudyCards
    with TableInfo<$LocalStudyCardsTable, LocalStudyCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStudyCardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelTypeMeta = const VerificationMeta(
    'modelType',
  );
  @override
  late final GeneratedColumn<String> modelType = GeneratedColumn<String>(
    'model_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transliterationMeta = const VerificationMeta(
    'transliteration',
  );
  @override
  late final GeneratedColumn<String> transliteration = GeneratedColumn<String>(
    'transliteration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _examplesJsonMeta = const VerificationMeta(
    'examplesJson',
  );
  @override
  late final GeneratedColumn<String> examplesJson = GeneratedColumn<String>(
    'examples_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learningStatusMeta = const VerificationMeta(
    'learningStatus',
  );
  @override
  late final GeneratedColumn<String> learningStatus = GeneratedColumn<String>(
    'learning_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_started'),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleJsonMeta = const VerificationMeta(
    'scheduleJson',
  );
  @override
  late final GeneratedColumn<String> scheduleJson = GeneratedColumn<String>(
    'schedule_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewHistoryJsonMeta = const VerificationMeta(
    'reviewHistoryJson',
  );
  @override
  late final GeneratedColumn<String> reviewHistoryJson =
      GeneratedColumn<String>(
        'review_history_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sourceBookIdMeta = const VerificationMeta(
    'sourceBookId',
  );
  @override
  late final GeneratedColumn<int> sourceBookId = GeneratedColumn<int>(
    'source_book_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceBookNameMeta = const VerificationMeta(
    'sourceBookName',
  );
  @override
  late final GeneratedColumn<String> sourceBookName = GeneratedColumn<String>(
    'source_book_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
    accountKey,
    remoteId,
    modelType,
    front,
    back,
    transliteration,
    audioUrl,
    examplesJson,
    tagsJson,
    learningStatus,
    dueAt,
    scheduleJson,
    reviewHistoryJson,
    suspended,
    sourceBookId,
    sourceBookName,
    updatedAt,
    syncState,
    deletedLocally,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_study_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStudyCardRow> instance, {
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
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('model_type')) {
      context.handle(
        _modelTypeMeta,
        modelType.isAcceptableOrUnknown(data['model_type']!, _modelTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_modelTypeMeta);
    }
    if (data.containsKey('front')) {
      context.handle(
        _frontMeta,
        front.isAcceptableOrUnknown(data['front']!, _frontMeta),
      );
    } else if (isInserting) {
      context.missing(_frontMeta);
    }
    if (data.containsKey('back')) {
      context.handle(
        _backMeta,
        back.isAcceptableOrUnknown(data['back']!, _backMeta),
      );
    } else if (isInserting) {
      context.missing(_backMeta);
    }
    if (data.containsKey('transliteration')) {
      context.handle(
        _transliterationMeta,
        transliteration.isAcceptableOrUnknown(
          data['transliteration']!,
          _transliterationMeta,
        ),
      );
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    }
    if (data.containsKey('examples_json')) {
      context.handle(
        _examplesJsonMeta,
        examplesJson.isAcceptableOrUnknown(
          data['examples_json']!,
          _examplesJsonMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsJsonMeta);
    }
    if (data.containsKey('learning_status')) {
      context.handle(
        _learningStatusMeta,
        learningStatus.isAcceptableOrUnknown(
          data['learning_status']!,
          _learningStatusMeta,
        ),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('schedule_json')) {
      context.handle(
        _scheduleJsonMeta,
        scheduleJson.isAcceptableOrUnknown(
          data['schedule_json']!,
          _scheduleJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleJsonMeta);
    }
    if (data.containsKey('review_history_json')) {
      context.handle(
        _reviewHistoryJsonMeta,
        reviewHistoryJson.isAcceptableOrUnknown(
          data['review_history_json']!,
          _reviewHistoryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewHistoryJsonMeta);
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    } else if (isInserting) {
      context.missing(_suspendedMeta);
    }
    if (data.containsKey('source_book_id')) {
      context.handle(
        _sourceBookIdMeta,
        sourceBookId.isAcceptableOrUnknown(
          data['source_book_id']!,
          _sourceBookIdMeta,
        ),
      );
    }
    if (data.containsKey('source_book_name')) {
      context.handle(
        _sourceBookNameMeta,
        sourceBookName.isAcceptableOrUnknown(
          data['source_book_name']!,
          _sourceBookNameMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {accountKey, remoteId};
  @override
  LocalStudyCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStudyCardRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      )!,
      modelType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_type'],
      )!,
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      )!,
      back: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back'],
      )!,
      transliteration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transliteration'],
      ),
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      ),
      examplesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}examples_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      learningStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_status'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      scheduleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_json'],
      )!,
      reviewHistoryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_history_json'],
      )!,
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
      sourceBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_book_id'],
      ),
      sourceBookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_book_name'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
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
  $LocalStudyCardsTable createAlias(String alias) {
    return $LocalStudyCardsTable(attachedDatabase, alias);
  }
}

class LocalStudyCardRow extends DataClass
    implements Insertable<LocalStudyCardRow> {
  final String accountKey;
  final int remoteId;
  final String modelType;
  final String front;
  final String back;
  final String? transliteration;
  final String? audioUrl;
  final String examplesJson;
  final String tagsJson;
  final String learningStatus;
  final DateTime? dueAt;
  final String scheduleJson;
  final String reviewHistoryJson;
  final bool suspended;
  final int? sourceBookId;
  final String? sourceBookName;
  final DateTime? updatedAt;
  final String syncState;
  final bool deletedLocally;
  const LocalStudyCardRow({
    required this.accountKey,
    required this.remoteId,
    required this.modelType,
    required this.front,
    required this.back,
    this.transliteration,
    this.audioUrl,
    required this.examplesJson,
    required this.tagsJson,
    required this.learningStatus,
    this.dueAt,
    required this.scheduleJson,
    required this.reviewHistoryJson,
    required this.suspended,
    this.sourceBookId,
    this.sourceBookName,
    this.updatedAt,
    required this.syncState,
    required this.deletedLocally,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['remote_id'] = Variable<int>(remoteId);
    map['model_type'] = Variable<String>(modelType);
    map['front'] = Variable<String>(front);
    map['back'] = Variable<String>(back);
    if (!nullToAbsent || transliteration != null) {
      map['transliteration'] = Variable<String>(transliteration);
    }
    if (!nullToAbsent || audioUrl != null) {
      map['audio_url'] = Variable<String>(audioUrl);
    }
    map['examples_json'] = Variable<String>(examplesJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['learning_status'] = Variable<String>(learningStatus);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['schedule_json'] = Variable<String>(scheduleJson);
    map['review_history_json'] = Variable<String>(reviewHistoryJson);
    map['suspended'] = Variable<bool>(suspended);
    if (!nullToAbsent || sourceBookId != null) {
      map['source_book_id'] = Variable<int>(sourceBookId);
    }
    if (!nullToAbsent || sourceBookName != null) {
      map['source_book_name'] = Variable<String>(sourceBookName);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['sync_state'] = Variable<String>(syncState);
    map['deleted_locally'] = Variable<bool>(deletedLocally);
    return map;
  }

  LocalStudyCardsCompanion toCompanion(bool nullToAbsent) {
    return LocalStudyCardsCompanion(
      accountKey: Value(accountKey),
      remoteId: Value(remoteId),
      modelType: Value(modelType),
      front: Value(front),
      back: Value(back),
      transliteration: transliteration == null && nullToAbsent
          ? const Value.absent()
          : Value(transliteration),
      audioUrl: audioUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(audioUrl),
      examplesJson: Value(examplesJson),
      tagsJson: Value(tagsJson),
      learningStatus: Value(learningStatus),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      scheduleJson: Value(scheduleJson),
      reviewHistoryJson: Value(reviewHistoryJson),
      suspended: Value(suspended),
      sourceBookId: sourceBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookId),
      sourceBookName: sourceBookName == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookName),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      syncState: Value(syncState),
      deletedLocally: Value(deletedLocally),
    );
  }

  factory LocalStudyCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStudyCardRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      remoteId: serializer.fromJson<int>(json['remoteId']),
      modelType: serializer.fromJson<String>(json['modelType']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      transliteration: serializer.fromJson<String?>(json['transliteration']),
      audioUrl: serializer.fromJson<String?>(json['audioUrl']),
      examplesJson: serializer.fromJson<String>(json['examplesJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      learningStatus: serializer.fromJson<String>(json['learningStatus']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      scheduleJson: serializer.fromJson<String>(json['scheduleJson']),
      reviewHistoryJson: serializer.fromJson<String>(json['reviewHistoryJson']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      sourceBookId: serializer.fromJson<int?>(json['sourceBookId']),
      sourceBookName: serializer.fromJson<String?>(json['sourceBookName']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
      deletedLocally: serializer.fromJson<bool>(json['deletedLocally']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'remoteId': serializer.toJson<int>(remoteId),
      'modelType': serializer.toJson<String>(modelType),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'transliteration': serializer.toJson<String?>(transliteration),
      'audioUrl': serializer.toJson<String?>(audioUrl),
      'examplesJson': serializer.toJson<String>(examplesJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'learningStatus': serializer.toJson<String>(learningStatus),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'scheduleJson': serializer.toJson<String>(scheduleJson),
      'reviewHistoryJson': serializer.toJson<String>(reviewHistoryJson),
      'suspended': serializer.toJson<bool>(suspended),
      'sourceBookId': serializer.toJson<int?>(sourceBookId),
      'sourceBookName': serializer.toJson<String?>(sourceBookName),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'syncState': serializer.toJson<String>(syncState),
      'deletedLocally': serializer.toJson<bool>(deletedLocally),
    };
  }

  LocalStudyCardRow copyWith({
    String? accountKey,
    int? remoteId,
    String? modelType,
    String? front,
    String? back,
    Value<String?> transliteration = const Value.absent(),
    Value<String?> audioUrl = const Value.absent(),
    String? examplesJson,
    String? tagsJson,
    String? learningStatus,
    Value<DateTime?> dueAt = const Value.absent(),
    String? scheduleJson,
    String? reviewHistoryJson,
    bool? suspended,
    Value<int?> sourceBookId = const Value.absent(),
    Value<String?> sourceBookName = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    String? syncState,
    bool? deletedLocally,
  }) => LocalStudyCardRow(
    accountKey: accountKey ?? this.accountKey,
    remoteId: remoteId ?? this.remoteId,
    modelType: modelType ?? this.modelType,
    front: front ?? this.front,
    back: back ?? this.back,
    transliteration: transliteration.present
        ? transliteration.value
        : this.transliteration,
    audioUrl: audioUrl.present ? audioUrl.value : this.audioUrl,
    examplesJson: examplesJson ?? this.examplesJson,
    tagsJson: tagsJson ?? this.tagsJson,
    learningStatus: learningStatus ?? this.learningStatus,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    scheduleJson: scheduleJson ?? this.scheduleJson,
    reviewHistoryJson: reviewHistoryJson ?? this.reviewHistoryJson,
    suspended: suspended ?? this.suspended,
    sourceBookId: sourceBookId.present ? sourceBookId.value : this.sourceBookId,
    sourceBookName: sourceBookName.present
        ? sourceBookName.value
        : this.sourceBookName,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    syncState: syncState ?? this.syncState,
    deletedLocally: deletedLocally ?? this.deletedLocally,
  );
  LocalStudyCardRow copyWithCompanion(LocalStudyCardsCompanion data) {
    return LocalStudyCardRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      modelType: data.modelType.present ? data.modelType.value : this.modelType,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      transliteration: data.transliteration.present
          ? data.transliteration.value
          : this.transliteration,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      examplesJson: data.examplesJson.present
          ? data.examplesJson.value
          : this.examplesJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      learningStatus: data.learningStatus.present
          ? data.learningStatus.value
          : this.learningStatus,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      scheduleJson: data.scheduleJson.present
          ? data.scheduleJson.value
          : this.scheduleJson,
      reviewHistoryJson: data.reviewHistoryJson.present
          ? data.reviewHistoryJson.value
          : this.reviewHistoryJson,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      sourceBookId: data.sourceBookId.present
          ? data.sourceBookId.value
          : this.sourceBookId,
      sourceBookName: data.sourceBookName.present
          ? data.sourceBookName.value
          : this.sourceBookName,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      deletedLocally: data.deletedLocally.present
          ? data.deletedLocally.value
          : this.deletedLocally,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudyCardRow(')
          ..write('accountKey: $accountKey, ')
          ..write('remoteId: $remoteId, ')
          ..write('modelType: $modelType, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('transliteration: $transliteration, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('learningStatus: $learningStatus, ')
          ..write('dueAt: $dueAt, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('reviewHistoryJson: $reviewHistoryJson, ')
          ..write('suspended: $suspended, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceBookName: $sourceBookName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('deletedLocally: $deletedLocally')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountKey,
    remoteId,
    modelType,
    front,
    back,
    transliteration,
    audioUrl,
    examplesJson,
    tagsJson,
    learningStatus,
    dueAt,
    scheduleJson,
    reviewHistoryJson,
    suspended,
    sourceBookId,
    sourceBookName,
    updatedAt,
    syncState,
    deletedLocally,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStudyCardRow &&
          other.accountKey == this.accountKey &&
          other.remoteId == this.remoteId &&
          other.modelType == this.modelType &&
          other.front == this.front &&
          other.back == this.back &&
          other.transliteration == this.transliteration &&
          other.audioUrl == this.audioUrl &&
          other.examplesJson == this.examplesJson &&
          other.tagsJson == this.tagsJson &&
          other.learningStatus == this.learningStatus &&
          other.dueAt == this.dueAt &&
          other.scheduleJson == this.scheduleJson &&
          other.reviewHistoryJson == this.reviewHistoryJson &&
          other.suspended == this.suspended &&
          other.sourceBookId == this.sourceBookId &&
          other.sourceBookName == this.sourceBookName &&
          other.updatedAt == this.updatedAt &&
          other.syncState == this.syncState &&
          other.deletedLocally == this.deletedLocally);
}

class LocalStudyCardsCompanion extends UpdateCompanion<LocalStudyCardRow> {
  final Value<String> accountKey;
  final Value<int> remoteId;
  final Value<String> modelType;
  final Value<String> front;
  final Value<String> back;
  final Value<String?> transliteration;
  final Value<String?> audioUrl;
  final Value<String> examplesJson;
  final Value<String> tagsJson;
  final Value<String> learningStatus;
  final Value<DateTime?> dueAt;
  final Value<String> scheduleJson;
  final Value<String> reviewHistoryJson;
  final Value<bool> suspended;
  final Value<int?> sourceBookId;
  final Value<String?> sourceBookName;
  final Value<DateTime?> updatedAt;
  final Value<String> syncState;
  final Value<bool> deletedLocally;
  final Value<int> rowid;
  const LocalStudyCardsCompanion({
    this.accountKey = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.modelType = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.transliteration = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.examplesJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.learningStatus = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.scheduleJson = const Value.absent(),
    this.reviewHistoryJson = const Value.absent(),
    this.suspended = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourceBookName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.deletedLocally = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStudyCardsCompanion.insert({
    required String accountKey,
    required int remoteId,
    required String modelType,
    required String front,
    required String back,
    this.transliteration = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.examplesJson = const Value.absent(),
    required String tagsJson,
    this.learningStatus = const Value.absent(),
    this.dueAt = const Value.absent(),
    required String scheduleJson,
    required String reviewHistoryJson,
    required bool suspended,
    this.sourceBookId = const Value.absent(),
    this.sourceBookName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required String syncState,
    this.deletedLocally = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       remoteId = Value(remoteId),
       modelType = Value(modelType),
       front = Value(front),
       back = Value(back),
       tagsJson = Value(tagsJson),
       scheduleJson = Value(scheduleJson),
       reviewHistoryJson = Value(reviewHistoryJson),
       suspended = Value(suspended),
       syncState = Value(syncState);
  static Insertable<LocalStudyCardRow> custom({
    Expression<String>? accountKey,
    Expression<int>? remoteId,
    Expression<String>? modelType,
    Expression<String>? front,
    Expression<String>? back,
    Expression<String>? transliteration,
    Expression<String>? audioUrl,
    Expression<String>? examplesJson,
    Expression<String>? tagsJson,
    Expression<String>? learningStatus,
    Expression<DateTime>? dueAt,
    Expression<String>? scheduleJson,
    Expression<String>? reviewHistoryJson,
    Expression<bool>? suspended,
    Expression<int>? sourceBookId,
    Expression<String>? sourceBookName,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncState,
    Expression<bool>? deletedLocally,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (remoteId != null) 'remote_id': remoteId,
      if (modelType != null) 'model_type': modelType,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (transliteration != null) 'transliteration': transliteration,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (examplesJson != null) 'examples_json': examplesJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (learningStatus != null) 'learning_status': learningStatus,
      if (dueAt != null) 'due_at': dueAt,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
      if (reviewHistoryJson != null) 'review_history_json': reviewHistoryJson,
      if (suspended != null) 'suspended': suspended,
      if (sourceBookId != null) 'source_book_id': sourceBookId,
      if (sourceBookName != null) 'source_book_name': sourceBookName,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncState != null) 'sync_state': syncState,
      if (deletedLocally != null) 'deleted_locally': deletedLocally,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStudyCardsCompanion copyWith({
    Value<String>? accountKey,
    Value<int>? remoteId,
    Value<String>? modelType,
    Value<String>? front,
    Value<String>? back,
    Value<String?>? transliteration,
    Value<String?>? audioUrl,
    Value<String>? examplesJson,
    Value<String>? tagsJson,
    Value<String>? learningStatus,
    Value<DateTime?>? dueAt,
    Value<String>? scheduleJson,
    Value<String>? reviewHistoryJson,
    Value<bool>? suspended,
    Value<int?>? sourceBookId,
    Value<String?>? sourceBookName,
    Value<DateTime?>? updatedAt,
    Value<String>? syncState,
    Value<bool>? deletedLocally,
    Value<int>? rowid,
  }) {
    return LocalStudyCardsCompanion(
      accountKey: accountKey ?? this.accountKey,
      remoteId: remoteId ?? this.remoteId,
      modelType: modelType ?? this.modelType,
      front: front ?? this.front,
      back: back ?? this.back,
      transliteration: transliteration ?? this.transliteration,
      audioUrl: audioUrl ?? this.audioUrl,
      examplesJson: examplesJson ?? this.examplesJson,
      tagsJson: tagsJson ?? this.tagsJson,
      learningStatus: learningStatus ?? this.learningStatus,
      dueAt: dueAt ?? this.dueAt,
      scheduleJson: scheduleJson ?? this.scheduleJson,
      reviewHistoryJson: reviewHistoryJson ?? this.reviewHistoryJson,
      suspended: suspended ?? this.suspended,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      sourceBookName: sourceBookName ?? this.sourceBookName,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      deletedLocally: deletedLocally ?? this.deletedLocally,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (modelType.present) {
      map['model_type'] = Variable<String>(modelType.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (transliteration.present) {
      map['transliteration'] = Variable<String>(transliteration.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (examplesJson.present) {
      map['examples_json'] = Variable<String>(examplesJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (learningStatus.present) {
      map['learning_status'] = Variable<String>(learningStatus.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (scheduleJson.present) {
      map['schedule_json'] = Variable<String>(scheduleJson.value);
    }
    if (reviewHistoryJson.present) {
      map['review_history_json'] = Variable<String>(reviewHistoryJson.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (sourceBookId.present) {
      map['source_book_id'] = Variable<int>(sourceBookId.value);
    }
    if (sourceBookName.present) {
      map['source_book_name'] = Variable<String>(sourceBookName.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
    return (StringBuffer('LocalStudyCardsCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('remoteId: $remoteId, ')
          ..write('modelType: $modelType, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('transliteration: $transliteration, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('learningStatus: $learningStatus, ')
          ..write('dueAt: $dueAt, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('reviewHistoryJson: $reviewHistoryJson, ')
          ..write('suspended: $suspended, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceBookName: $sourceBookName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('deletedLocally: $deletedLocally, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CardsDatabase extends GeneratedDatabase {
  _$CardsDatabase(QueryExecutor e) : super(e);
  $CardsDatabaseManager get managers => $CardsDatabaseManager(this);
  late final $LocalStudyCardsTable localStudyCards = $LocalStudyCardsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localStudyCards];
}

typedef $$LocalStudyCardsTableCreateCompanionBuilder =
    LocalStudyCardsCompanion Function({
      required String accountKey,
      required int remoteId,
      required String modelType,
      required String front,
      required String back,
      Value<String?> transliteration,
      Value<String?> audioUrl,
      Value<String> examplesJson,
      required String tagsJson,
      Value<String> learningStatus,
      Value<DateTime?> dueAt,
      required String scheduleJson,
      required String reviewHistoryJson,
      required bool suspended,
      Value<int?> sourceBookId,
      Value<String?> sourceBookName,
      Value<DateTime?> updatedAt,
      required String syncState,
      Value<bool> deletedLocally,
      Value<int> rowid,
    });
typedef $$LocalStudyCardsTableUpdateCompanionBuilder =
    LocalStudyCardsCompanion Function({
      Value<String> accountKey,
      Value<int> remoteId,
      Value<String> modelType,
      Value<String> front,
      Value<String> back,
      Value<String?> transliteration,
      Value<String?> audioUrl,
      Value<String> examplesJson,
      Value<String> tagsJson,
      Value<String> learningStatus,
      Value<DateTime?> dueAt,
      Value<String> scheduleJson,
      Value<String> reviewHistoryJson,
      Value<bool> suspended,
      Value<int?> sourceBookId,
      Value<String?> sourceBookName,
      Value<DateTime?> updatedAt,
      Value<String> syncState,
      Value<bool> deletedLocally,
      Value<int> rowid,
    });

class $$LocalStudyCardsTableFilterComposer
    extends Composer<_$CardsDatabase, $LocalStudyCardsTable> {
  $$LocalStudyCardsTableFilterComposer({
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

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningStatus => $composableBuilder(
    column: $table.learningStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewHistoryJson => $composableBuilder(
    column: $table.reviewHistoryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBookName => $composableBuilder(
    column: $table.sourceBookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$LocalStudyCardsTableOrderingComposer
    extends Composer<_$CardsDatabase, $LocalStudyCardsTable> {
  $$LocalStudyCardsTableOrderingComposer({
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

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelType => $composableBuilder(
    column: $table.modelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningStatus => $composableBuilder(
    column: $table.learningStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewHistoryJson => $composableBuilder(
    column: $table.reviewHistoryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBookName => $composableBuilder(
    column: $table.sourceBookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$LocalStudyCardsTableAnnotationComposer
    extends Composer<_$CardsDatabase, $LocalStudyCardsTable> {
  $$LocalStudyCardsTableAnnotationComposer({
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

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get modelType =>
      $composableBuilder(column: $table.modelType, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<String> get transliteration => $composableBuilder(
    column: $table.transliteration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get learningStatus => $composableBuilder(
    column: $table.learningStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewHistoryJson => $composableBuilder(
    column: $table.reviewHistoryJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<int> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceBookName => $composableBuilder(
    column: $table.sourceBookName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<bool> get deletedLocally => $composableBuilder(
    column: $table.deletedLocally,
    builder: (column) => column,
  );
}

class $$LocalStudyCardsTableTableManager
    extends
        RootTableManager<
          _$CardsDatabase,
          $LocalStudyCardsTable,
          LocalStudyCardRow,
          $$LocalStudyCardsTableFilterComposer,
          $$LocalStudyCardsTableOrderingComposer,
          $$LocalStudyCardsTableAnnotationComposer,
          $$LocalStudyCardsTableCreateCompanionBuilder,
          $$LocalStudyCardsTableUpdateCompanionBuilder,
          (
            LocalStudyCardRow,
            BaseReferences<
              _$CardsDatabase,
              $LocalStudyCardsTable,
              LocalStudyCardRow
            >,
          ),
          LocalStudyCardRow,
          PrefetchHooks Function()
        > {
  $$LocalStudyCardsTableTableManager(
    _$CardsDatabase db,
    $LocalStudyCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStudyCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStudyCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStudyCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<int> remoteId = const Value.absent(),
                Value<String> modelType = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<String?> transliteration = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<String> examplesJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> learningStatus = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<String> scheduleJson = const Value.absent(),
                Value<String> reviewHistoryJson = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<int?> sourceBookId = const Value.absent(),
                Value<String?> sourceBookName = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<bool> deletedLocally = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudyCardsCompanion(
                accountKey: accountKey,
                remoteId: remoteId,
                modelType: modelType,
                front: front,
                back: back,
                transliteration: transliteration,
                audioUrl: audioUrl,
                examplesJson: examplesJson,
                tagsJson: tagsJson,
                learningStatus: learningStatus,
                dueAt: dueAt,
                scheduleJson: scheduleJson,
                reviewHistoryJson: reviewHistoryJson,
                suspended: suspended,
                sourceBookId: sourceBookId,
                sourceBookName: sourceBookName,
                updatedAt: updatedAt,
                syncState: syncState,
                deletedLocally: deletedLocally,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required int remoteId,
                required String modelType,
                required String front,
                required String back,
                Value<String?> transliteration = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<String> examplesJson = const Value.absent(),
                required String tagsJson,
                Value<String> learningStatus = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                required String scheduleJson,
                required String reviewHistoryJson,
                required bool suspended,
                Value<int?> sourceBookId = const Value.absent(),
                Value<String?> sourceBookName = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                required String syncState,
                Value<bool> deletedLocally = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStudyCardsCompanion.insert(
                accountKey: accountKey,
                remoteId: remoteId,
                modelType: modelType,
                front: front,
                back: back,
                transliteration: transliteration,
                audioUrl: audioUrl,
                examplesJson: examplesJson,
                tagsJson: tagsJson,
                learningStatus: learningStatus,
                dueAt: dueAt,
                scheduleJson: scheduleJson,
                reviewHistoryJson: reviewHistoryJson,
                suspended: suspended,
                sourceBookId: sourceBookId,
                sourceBookName: sourceBookName,
                updatedAt: updatedAt,
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

typedef $$LocalStudyCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$CardsDatabase,
      $LocalStudyCardsTable,
      LocalStudyCardRow,
      $$LocalStudyCardsTableFilterComposer,
      $$LocalStudyCardsTableOrderingComposer,
      $$LocalStudyCardsTableAnnotationComposer,
      $$LocalStudyCardsTableCreateCompanionBuilder,
      $$LocalStudyCardsTableUpdateCompanionBuilder,
      (
        LocalStudyCardRow,
        BaseReferences<
          _$CardsDatabase,
          $LocalStudyCardsTable,
          LocalStudyCardRow
        >,
      ),
      LocalStudyCardRow,
      PrefetchHooks Function()
    >;

class $CardsDatabaseManager {
  final _$CardsDatabase _db;
  $CardsDatabaseManager(this._db);
  $$LocalStudyCardsTableTableManager get localStudyCards =>
      $$LocalStudyCardsTableTableManager(_db, _db.localStudyCards);
}
