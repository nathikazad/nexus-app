// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cards_database.dart';

// ignore_for_file: type=lint
class $LocalCardDecksTable extends LocalCardDecks
    with TableInfo<$LocalCardDecksTable, LocalCardDeckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCardDecksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromLanguageMeta = const VerificationMeta(
    'fromLanguage',
  );
  @override
  late final GeneratedColumn<String> fromLanguage = GeneratedColumn<String>(
    'from_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLanguageMeta = const VerificationMeta(
    'toLanguage',
  );
  @override
  late final GeneratedColumn<String> toLanguage = GeneratedColumn<String>(
    'to_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
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
  static const VerificationMeta _serverHashMeta = const VerificationMeta(
    'serverHash',
  );
  @override
  late final GeneratedColumn<String> serverHash = GeneratedColumn<String>(
    'server_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    remoteId,
    name,
    description,
    language,
    fromLanguage,
    toLanguage,
    archived,
    updatedAt,
    serverHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_card_decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCardDeckRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('from_language')) {
      context.handle(
        _fromLanguageMeta,
        fromLanguage.isAcceptableOrUnknown(
          data['from_language']!,
          _fromLanguageMeta,
        ),
      );
    }
    if (data.containsKey('to_language')) {
      context.handle(
        _toLanguageMeta,
        toLanguage.isAcceptableOrUnknown(data['to_language']!, _toLanguageMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    } else if (isInserting) {
      context.missing(_archivedMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('server_hash')) {
      context.handle(
        _serverHashMeta,
        serverHash.isAcceptableOrUnknown(data['server_hash']!, _serverHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, remoteId};
  @override
  LocalCardDeckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCardDeckRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      fromLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_language'],
      ),
      toLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_language'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      serverHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_hash'],
      ),
    );
  }

  @override
  $LocalCardDecksTable createAlias(String alias) {
    return $LocalCardDecksTable(attachedDatabase, alias);
  }
}

class LocalCardDeckRow extends DataClass
    implements Insertable<LocalCardDeckRow> {
  final String accountKey;
  final int remoteId;
  final String name;
  final String description;
  final String? language;
  final String? fromLanguage;
  final String? toLanguage;
  final bool archived;
  final DateTime? updatedAt;
  final String? serverHash;
  const LocalCardDeckRow({
    required this.accountKey,
    required this.remoteId,
    required this.name,
    required this.description,
    this.language,
    this.fromLanguage,
    this.toLanguage,
    required this.archived,
    this.updatedAt,
    this.serverHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['remote_id'] = Variable<int>(remoteId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || fromLanguage != null) {
      map['from_language'] = Variable<String>(fromLanguage);
    }
    if (!nullToAbsent || toLanguage != null) {
      map['to_language'] = Variable<String>(toLanguage);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || serverHash != null) {
      map['server_hash'] = Variable<String>(serverHash);
    }
    return map;
  }

  LocalCardDecksCompanion toCompanion(bool nullToAbsent) {
    return LocalCardDecksCompanion(
      accountKey: Value(accountKey),
      remoteId: Value(remoteId),
      name: Value(name),
      description: Value(description),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      fromLanguage: fromLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(fromLanguage),
      toLanguage: toLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(toLanguage),
      archived: Value(archived),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      serverHash: serverHash == null && nullToAbsent
          ? const Value.absent()
          : Value(serverHash),
    );
  }

  factory LocalCardDeckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCardDeckRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      remoteId: serializer.fromJson<int>(json['remoteId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      language: serializer.fromJson<String?>(json['language']),
      fromLanguage: serializer.fromJson<String?>(json['fromLanguage']),
      toLanguage: serializer.fromJson<String?>(json['toLanguage']),
      archived: serializer.fromJson<bool>(json['archived']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      serverHash: serializer.fromJson<String?>(json['serverHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'remoteId': serializer.toJson<int>(remoteId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'language': serializer.toJson<String?>(language),
      'fromLanguage': serializer.toJson<String?>(fromLanguage),
      'toLanguage': serializer.toJson<String?>(toLanguage),
      'archived': serializer.toJson<bool>(archived),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'serverHash': serializer.toJson<String?>(serverHash),
    };
  }

  LocalCardDeckRow copyWith({
    String? accountKey,
    int? remoteId,
    String? name,
    String? description,
    Value<String?> language = const Value.absent(),
    Value<String?> fromLanguage = const Value.absent(),
    Value<String?> toLanguage = const Value.absent(),
    bool? archived,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<String?> serverHash = const Value.absent(),
  }) => LocalCardDeckRow(
    accountKey: accountKey ?? this.accountKey,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    description: description ?? this.description,
    language: language.present ? language.value : this.language,
    fromLanguage: fromLanguage.present ? fromLanguage.value : this.fromLanguage,
    toLanguage: toLanguage.present ? toLanguage.value : this.toLanguage,
    archived: archived ?? this.archived,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    serverHash: serverHash.present ? serverHash.value : this.serverHash,
  );
  LocalCardDeckRow copyWithCompanion(LocalCardDecksCompanion data) {
    return LocalCardDeckRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      language: data.language.present ? data.language.value : this.language,
      fromLanguage: data.fromLanguage.present
          ? data.fromLanguage.value
          : this.fromLanguage,
      toLanguage: data.toLanguage.present
          ? data.toLanguage.value
          : this.toLanguage,
      archived: data.archived.present ? data.archived.value : this.archived,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverHash: data.serverHash.present
          ? data.serverHash.value
          : this.serverHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCardDeckRow(')
          ..write('accountKey: $accountKey, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('language: $language, ')
          ..write('fromLanguage: $fromLanguage, ')
          ..write('toLanguage: $toLanguage, ')
          ..write('archived: $archived, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverHash: $serverHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountKey,
    remoteId,
    name,
    description,
    language,
    fromLanguage,
    toLanguage,
    archived,
    updatedAt,
    serverHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCardDeckRow &&
          other.accountKey == this.accountKey &&
          other.remoteId == this.remoteId &&
          other.name == this.name &&
          other.description == this.description &&
          other.language == this.language &&
          other.fromLanguage == this.fromLanguage &&
          other.toLanguage == this.toLanguage &&
          other.archived == this.archived &&
          other.updatedAt == this.updatedAt &&
          other.serverHash == this.serverHash);
}

class LocalCardDecksCompanion extends UpdateCompanion<LocalCardDeckRow> {
  final Value<String> accountKey;
  final Value<int> remoteId;
  final Value<String> name;
  final Value<String> description;
  final Value<String?> language;
  final Value<String?> fromLanguage;
  final Value<String?> toLanguage;
  final Value<bool> archived;
  final Value<DateTime?> updatedAt;
  final Value<String?> serverHash;
  final Value<int> rowid;
  const LocalCardDecksCompanion({
    this.accountKey = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.language = const Value.absent(),
    this.fromLanguage = const Value.absent(),
    this.toLanguage = const Value.absent(),
    this.archived = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCardDecksCompanion.insert({
    required String accountKey,
    required int remoteId,
    required String name,
    required String description,
    this.language = const Value.absent(),
    this.fromLanguage = const Value.absent(),
    this.toLanguage = const Value.absent(),
    required bool archived,
    this.updatedAt = const Value.absent(),
    this.serverHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       remoteId = Value(remoteId),
       name = Value(name),
       description = Value(description),
       archived = Value(archived);
  static Insertable<LocalCardDeckRow> custom({
    Expression<String>? accountKey,
    Expression<int>? remoteId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? language,
    Expression<String>? fromLanguage,
    Expression<String>? toLanguage,
    Expression<bool>? archived,
    Expression<DateTime>? updatedAt,
    Expression<String>? serverHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (remoteId != null) 'remote_id': remoteId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (language != null) 'language': language,
      if (fromLanguage != null) 'from_language': fromLanguage,
      if (toLanguage != null) 'to_language': toLanguage,
      if (archived != null) 'archived': archived,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverHash != null) 'server_hash': serverHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCardDecksCompanion copyWith({
    Value<String>? accountKey,
    Value<int>? remoteId,
    Value<String>? name,
    Value<String>? description,
    Value<String?>? language,
    Value<String?>? fromLanguage,
    Value<String?>? toLanguage,
    Value<bool>? archived,
    Value<DateTime?>? updatedAt,
    Value<String?>? serverHash,
    Value<int>? rowid,
  }) {
    return LocalCardDecksCompanion(
      accountKey: accountKey ?? this.accountKey,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      description: description ?? this.description,
      language: language ?? this.language,
      fromLanguage: fromLanguage ?? this.fromLanguage,
      toLanguage: toLanguage ?? this.toLanguage,
      archived: archived ?? this.archived,
      updatedAt: updatedAt ?? this.updatedAt,
      serverHash: serverHash ?? this.serverHash,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (fromLanguage.present) {
      map['from_language'] = Variable<String>(fromLanguage.value);
    }
    if (toLanguage.present) {
      map['to_language'] = Variable<String>(toLanguage.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverHash.present) {
      map['server_hash'] = Variable<String>(serverHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCardDecksCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('remoteId: $remoteId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('language: $language, ')
          ..write('fromLanguage: $fromLanguage, ')
          ..write('toLanguage: $toLanguage, ')
          ..write('archived: $archived, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverHash: $serverHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<int> deckId = GeneratedColumn<int>(
    'deck_id',
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
    deckId,
    modelType,
    front,
    back,
    transliteration,
    audioUrl,
    examplesJson,
    tagsJson,
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
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
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
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deck_id'],
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
  final int deckId;
  final String modelType;
  final String front;
  final String back;
  final String? transliteration;
  final String? audioUrl;
  final String examplesJson;
  final String tagsJson;
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
    required this.deckId,
    required this.modelType,
    required this.front,
    required this.back,
    this.transliteration,
    this.audioUrl,
    required this.examplesJson,
    required this.tagsJson,
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
    map['deck_id'] = Variable<int>(deckId);
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
      deckId: Value(deckId),
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
      deckId: serializer.fromJson<int>(json['deckId']),
      modelType: serializer.fromJson<String>(json['modelType']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      transliteration: serializer.fromJson<String?>(json['transliteration']),
      audioUrl: serializer.fromJson<String?>(json['audioUrl']),
      examplesJson: serializer.fromJson<String>(json['examplesJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
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
      'deckId': serializer.toJson<int>(deckId),
      'modelType': serializer.toJson<String>(modelType),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'transliteration': serializer.toJson<String?>(transliteration),
      'audioUrl': serializer.toJson<String?>(audioUrl),
      'examplesJson': serializer.toJson<String>(examplesJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
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
    int? deckId,
    String? modelType,
    String? front,
    String? back,
    Value<String?> transliteration = const Value.absent(),
    Value<String?> audioUrl = const Value.absent(),
    String? examplesJson,
    String? tagsJson,
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
    deckId: deckId ?? this.deckId,
    modelType: modelType ?? this.modelType,
    front: front ?? this.front,
    back: back ?? this.back,
    transliteration: transliteration.present
        ? transliteration.value
        : this.transliteration,
    audioUrl: audioUrl.present ? audioUrl.value : this.audioUrl,
    examplesJson: examplesJson ?? this.examplesJson,
    tagsJson: tagsJson ?? this.tagsJson,
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
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
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
          ..write('deckId: $deckId, ')
          ..write('modelType: $modelType, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('transliteration: $transliteration, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('tagsJson: $tagsJson, ')
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
    deckId,
    modelType,
    front,
    back,
    transliteration,
    audioUrl,
    examplesJson,
    tagsJson,
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
          other.deckId == this.deckId &&
          other.modelType == this.modelType &&
          other.front == this.front &&
          other.back == this.back &&
          other.transliteration == this.transliteration &&
          other.audioUrl == this.audioUrl &&
          other.examplesJson == this.examplesJson &&
          other.tagsJson == this.tagsJson &&
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
  final Value<int> deckId;
  final Value<String> modelType;
  final Value<String> front;
  final Value<String> back;
  final Value<String?> transliteration;
  final Value<String?> audioUrl;
  final Value<String> examplesJson;
  final Value<String> tagsJson;
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
    this.deckId = const Value.absent(),
    this.modelType = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.transliteration = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.examplesJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
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
    required int deckId,
    required String modelType,
    required String front,
    required String back,
    this.transliteration = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.examplesJson = const Value.absent(),
    required String tagsJson,
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
       deckId = Value(deckId),
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
    Expression<int>? deckId,
    Expression<String>? modelType,
    Expression<String>? front,
    Expression<String>? back,
    Expression<String>? transliteration,
    Expression<String>? audioUrl,
    Expression<String>? examplesJson,
    Expression<String>? tagsJson,
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
      if (deckId != null) 'deck_id': deckId,
      if (modelType != null) 'model_type': modelType,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (transliteration != null) 'transliteration': transliteration,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (examplesJson != null) 'examples_json': examplesJson,
      if (tagsJson != null) 'tags_json': tagsJson,
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
    Value<int>? deckId,
    Value<String>? modelType,
    Value<String>? front,
    Value<String>? back,
    Value<String?>? transliteration,
    Value<String?>? audioUrl,
    Value<String>? examplesJson,
    Value<String>? tagsJson,
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
      deckId: deckId ?? this.deckId,
      modelType: modelType ?? this.modelType,
      front: front ?? this.front,
      back: back ?? this.back,
      transliteration: transliteration ?? this.transliteration,
      audioUrl: audioUrl ?? this.audioUrl,
      examplesJson: examplesJson ?? this.examplesJson,
      tagsJson: tagsJson ?? this.tagsJson,
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
    if (deckId.present) {
      map['deck_id'] = Variable<int>(deckId.value);
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
          ..write('deckId: $deckId, ')
          ..write('modelType: $modelType, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('transliteration: $transliteration, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('tagsJson: $tagsJson, ')
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
  late final $LocalCardDecksTable localCardDecks = $LocalCardDecksTable(this);
  late final $LocalStudyCardsTable localStudyCards = $LocalStudyCardsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localCardDecks,
    localStudyCards,
  ];
}

typedef $$LocalCardDecksTableCreateCompanionBuilder =
    LocalCardDecksCompanion Function({
      required String accountKey,
      required int remoteId,
      required String name,
      required String description,
      Value<String?> language,
      Value<String?> fromLanguage,
      Value<String?> toLanguage,
      required bool archived,
      Value<DateTime?> updatedAt,
      Value<String?> serverHash,
      Value<int> rowid,
    });
typedef $$LocalCardDecksTableUpdateCompanionBuilder =
    LocalCardDecksCompanion Function({
      Value<String> accountKey,
      Value<int> remoteId,
      Value<String> name,
      Value<String> description,
      Value<String?> language,
      Value<String?> fromLanguage,
      Value<String?> toLanguage,
      Value<bool> archived,
      Value<DateTime?> updatedAt,
      Value<String?> serverHash,
      Value<int> rowid,
    });

class $$LocalCardDecksTableFilterComposer
    extends Composer<_$CardsDatabase, $LocalCardDecksTable> {
  $$LocalCardDecksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromLanguage => $composableBuilder(
    column: $table.fromLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLanguage => $composableBuilder(
    column: $table.toLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverHash => $composableBuilder(
    column: $table.serverHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCardDecksTableOrderingComposer
    extends Composer<_$CardsDatabase, $LocalCardDecksTable> {
  $$LocalCardDecksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromLanguage => $composableBuilder(
    column: $table.fromLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toLanguage => $composableBuilder(
    column: $table.toLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverHash => $composableBuilder(
    column: $table.serverHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCardDecksTableAnnotationComposer
    extends Composer<_$CardsDatabase, $LocalCardDecksTable> {
  $$LocalCardDecksTableAnnotationComposer({
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get fromLanguage => $composableBuilder(
    column: $table.fromLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toLanguage => $composableBuilder(
    column: $table.toLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get serverHash => $composableBuilder(
    column: $table.serverHash,
    builder: (column) => column,
  );
}

class $$LocalCardDecksTableTableManager
    extends
        RootTableManager<
          _$CardsDatabase,
          $LocalCardDecksTable,
          LocalCardDeckRow,
          $$LocalCardDecksTableFilterComposer,
          $$LocalCardDecksTableOrderingComposer,
          $$LocalCardDecksTableAnnotationComposer,
          $$LocalCardDecksTableCreateCompanionBuilder,
          $$LocalCardDecksTableUpdateCompanionBuilder,
          (
            LocalCardDeckRow,
            BaseReferences<
              _$CardsDatabase,
              $LocalCardDecksTable,
              LocalCardDeckRow
            >,
          ),
          LocalCardDeckRow,
          PrefetchHooks Function()
        > {
  $$LocalCardDecksTableTableManager(
    _$CardsDatabase db,
    $LocalCardDecksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCardDecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCardDecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCardDecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<int> remoteId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> fromLanguage = const Value.absent(),
                Value<String?> toLanguage = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> serverHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCardDecksCompanion(
                accountKey: accountKey,
                remoteId: remoteId,
                name: name,
                description: description,
                language: language,
                fromLanguage: fromLanguage,
                toLanguage: toLanguage,
                archived: archived,
                updatedAt: updatedAt,
                serverHash: serverHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required int remoteId,
                required String name,
                required String description,
                Value<String?> language = const Value.absent(),
                Value<String?> fromLanguage = const Value.absent(),
                Value<String?> toLanguage = const Value.absent(),
                required bool archived,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<String?> serverHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCardDecksCompanion.insert(
                accountKey: accountKey,
                remoteId: remoteId,
                name: name,
                description: description,
                language: language,
                fromLanguage: fromLanguage,
                toLanguage: toLanguage,
                archived: archived,
                updatedAt: updatedAt,
                serverHash: serverHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCardDecksTableProcessedTableManager =
    ProcessedTableManager<
      _$CardsDatabase,
      $LocalCardDecksTable,
      LocalCardDeckRow,
      $$LocalCardDecksTableFilterComposer,
      $$LocalCardDecksTableOrderingComposer,
      $$LocalCardDecksTableAnnotationComposer,
      $$LocalCardDecksTableCreateCompanionBuilder,
      $$LocalCardDecksTableUpdateCompanionBuilder,
      (
        LocalCardDeckRow,
        BaseReferences<_$CardsDatabase, $LocalCardDecksTable, LocalCardDeckRow>,
      ),
      LocalCardDeckRow,
      PrefetchHooks Function()
    >;
typedef $$LocalStudyCardsTableCreateCompanionBuilder =
    LocalStudyCardsCompanion Function({
      required String accountKey,
      required int remoteId,
      required int deckId,
      required String modelType,
      required String front,
      required String back,
      Value<String?> transliteration,
      Value<String?> audioUrl,
      Value<String> examplesJson,
      required String tagsJson,
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
      Value<int> deckId,
      Value<String> modelType,
      Value<String> front,
      Value<String> back,
      Value<String?> transliteration,
      Value<String?> audioUrl,
      Value<String> examplesJson,
      Value<String> tagsJson,
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

  ColumnFilters<int> get deckId => $composableBuilder(
    column: $table.deckId,
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

  ColumnOrderings<int> get deckId => $composableBuilder(
    column: $table.deckId,
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

  GeneratedColumn<int> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

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
                Value<int> deckId = const Value.absent(),
                Value<String> modelType = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<String?> transliteration = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<String> examplesJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
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
                deckId: deckId,
                modelType: modelType,
                front: front,
                back: back,
                transliteration: transliteration,
                audioUrl: audioUrl,
                examplesJson: examplesJson,
                tagsJson: tagsJson,
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
                required int deckId,
                required String modelType,
                required String front,
                required String back,
                Value<String?> transliteration = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<String> examplesJson = const Value.absent(),
                required String tagsJson,
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
                deckId: deckId,
                modelType: modelType,
                front: front,
                back: back,
                transliteration: transliteration,
                audioUrl: audioUrl,
                examplesJson: examplesJson,
                tagsJson: tagsJson,
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
  $$LocalCardDecksTableTableManager get localCardDecks =>
      $$LocalCardDecksTableTableManager(_db, _db.localCardDecks);
  $$LocalStudyCardsTableTableManager get localStudyCards =>
      $$LocalStudyCardsTableTableManager(_db, _db.localStudyCards);
}
