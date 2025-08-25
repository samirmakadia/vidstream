// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_storage_drift.dart';

// ignore_for_file: type=lint
class $ConversationsDbTable extends ConversationsDb
    with TableInfo<$ConversationsDbTable, ConversationsDbData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsDbTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _participantsMeta =
      const VerificationMeta('participants');
  @override
  late final GeneratedColumn<String> participants = GeneratedColumn<String>(
      'participants', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedForMeta =
      const VerificationMeta('deletedFor');
  @override
  late final GeneratedColumn<String> deletedFor = GeneratedColumn<String>(
      'deleted_for', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        participants,
        lastMessage,
        unreadCount,
        createdAt,
        updatedAt,
        deletedFor
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations_db';
  @override
  VerificationContext validateIntegrity(
      Insertable<ConversationsDbData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('participants')) {
      context.handle(
          _participantsMeta,
          participants.isAcceptableOrUnknown(
              data['participants']!, _participantsMeta));
    } else if (isInserting) {
      context.missing(_participantsMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_for')) {
      context.handle(
          _deletedForMeta,
          deletedFor.isAcceptableOrUnknown(
              data['deleted_for']!, _deletedForMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationsDbData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationsDbData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      participants: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}participants'])!,
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message']),
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      deletedFor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_for']),
    );
  }

  @override
  $ConversationsDbTable createAlias(String alias) {
    return $ConversationsDbTable(attachedDatabase, alias);
  }
}

class ConversationsDbData extends DataClass
    implements Insertable<ConversationsDbData> {
  final String id;
  final String conversationId;
  final String participants;
  final String? lastMessage;
  final int unreadCount;
  final int createdAt;
  final int updatedAt;
  final String? deletedFor;
  const ConversationsDbData(
      {required this.id,
      required this.conversationId,
      required this.participants,
      this.lastMessage,
      required this.unreadCount,
      required this.createdAt,
      required this.updatedAt,
      this.deletedFor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['participants'] = Variable<String>(participants);
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedFor != null) {
      map['deleted_for'] = Variable<String>(deletedFor);
    }
    return map;
  }

  ConversationsDbCompanion toCompanion(bool nullToAbsent) {
    return ConversationsDbCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      participants: Value(participants),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      unreadCount: Value(unreadCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedFor: deletedFor == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedFor),
    );
  }

  factory ConversationsDbData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationsDbData(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      participants: serializer.fromJson<String>(json['participants']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedFor: serializer.fromJson<String?>(json['deletedFor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'participants': serializer.toJson<String>(participants),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedFor': serializer.toJson<String?>(deletedFor),
    };
  }

  ConversationsDbData copyWith(
          {String? id,
          String? conversationId,
          String? participants,
          Value<String?> lastMessage = const Value.absent(),
          int? unreadCount,
          int? createdAt,
          int? updatedAt,
          Value<String?> deletedFor = const Value.absent()}) =>
      ConversationsDbData(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        participants: participants ?? this.participants,
        lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedFor: deletedFor.present ? deletedFor.value : this.deletedFor,
      );
  ConversationsDbData copyWithCompanion(ConversationsDbCompanion data) {
    return ConversationsDbData(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      participants: data.participants.present
          ? data.participants.value
          : this.participants,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedFor:
          data.deletedFor.present ? data.deletedFor.value : this.deletedFor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsDbData(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('participants: $participants, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedFor: $deletedFor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, participants, lastMessage,
      unreadCount, createdAt, updatedAt, deletedFor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationsDbData &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.participants == this.participants &&
          other.lastMessage == this.lastMessage &&
          other.unreadCount == this.unreadCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedFor == this.deletedFor);
}

class ConversationsDbCompanion extends UpdateCompanion<ConversationsDbData> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> participants;
  final Value<String?> lastMessage;
  final Value<int> unreadCount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> deletedFor;
  final Value<int> rowid;
  const ConversationsDbCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.participants = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedFor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsDbCompanion.insert({
    required String id,
    required String conversationId,
    required String participants,
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedFor = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        participants = Value(participants),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ConversationsDbData> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? participants,
    Expression<String>? lastMessage,
    Expression<int>? unreadCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deletedFor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (participants != null) 'participants': participants,
      if (lastMessage != null) 'last_message': lastMessage,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedFor != null) 'deleted_for': deletedFor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsDbCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? participants,
      Value<String?>? lastMessage,
      Value<int>? unreadCount,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<String?>? deletedFor,
      Value<int>? rowid}) {
    return ConversationsDbCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedFor: deletedFor ?? this.deletedFor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (participants.present) {
      map['participants'] = Variable<String>(participants.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedFor.present) {
      map['deleted_for'] = Variable<String>(deletedFor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsDbCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('participants: $participants, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedFor: $deletedFor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConversationDatabase extends GeneratedDatabase {
  _$ConversationDatabase(QueryExecutor e) : super(e);
  $ConversationDatabaseManager get managers =>
      $ConversationDatabaseManager(this);
  late final $ConversationsDbTable conversationsDb =
      $ConversationsDbTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [conversationsDb];
}

typedef $$ConversationsDbTableCreateCompanionBuilder = ConversationsDbCompanion
    Function({
  required String id,
  required String conversationId,
  required String participants,
  Value<String?> lastMessage,
  Value<int> unreadCount,
  required int createdAt,
  required int updatedAt,
  Value<String?> deletedFor,
  Value<int> rowid,
});
typedef $$ConversationsDbTableUpdateCompanionBuilder = ConversationsDbCompanion
    Function({
  Value<String> id,
  Value<String> conversationId,
  Value<String> participants,
  Value<String?> lastMessage,
  Value<int> unreadCount,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> deletedFor,
  Value<int> rowid,
});

class $$ConversationsDbTableFilterComposer
    extends Composer<_$ConversationDatabase, $ConversationsDbTable> {
  $$ConversationsDbTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get participants => $composableBuilder(
      column: $table.participants, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => ColumnFilters(column));
}

class $$ConversationsDbTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ConversationsDbTable> {
  $$ConversationsDbTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get participants => $composableBuilder(
      column: $table.participants,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => ColumnOrderings(column));
}

class $$ConversationsDbTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ConversationsDbTable> {
  $$ConversationsDbTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get participants => $composableBuilder(
      column: $table.participants, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => column);
}

class $$ConversationsDbTableTableManager extends RootTableManager<
    _$ConversationDatabase,
    $ConversationsDbTable,
    ConversationsDbData,
    $$ConversationsDbTableFilterComposer,
    $$ConversationsDbTableOrderingComposer,
    $$ConversationsDbTableAnnotationComposer,
    $$ConversationsDbTableCreateCompanionBuilder,
    $$ConversationsDbTableUpdateCompanionBuilder,
    (
      ConversationsDbData,
      BaseReferences<_$ConversationDatabase, $ConversationsDbTable,
          ConversationsDbData>
    ),
    ConversationsDbData,
    PrefetchHooks Function()> {
  $$ConversationsDbTableTableManager(
      _$ConversationDatabase db, $ConversationsDbTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsDbTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsDbTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsDbTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> participants = const Value.absent(),
            Value<String?> lastMessage = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<String?> deletedFor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsDbCompanion(
            id: id,
            conversationId: conversationId,
            participants: participants,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedFor: deletedFor,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String conversationId,
            required String participants,
            Value<String?> lastMessage = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<String?> deletedFor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConversationsDbCompanion.insert(
            id: id,
            conversationId: conversationId,
            participants: participants,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedFor: deletedFor,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConversationsDbTableProcessedTableManager = ProcessedTableManager<
    _$ConversationDatabase,
    $ConversationsDbTable,
    ConversationsDbData,
    $$ConversationsDbTableFilterComposer,
    $$ConversationsDbTableOrderingComposer,
    $$ConversationsDbTableAnnotationComposer,
    $$ConversationsDbTableCreateCompanionBuilder,
    $$ConversationsDbTableUpdateCompanionBuilder,
    (
      ConversationsDbData,
      BaseReferences<_$ConversationDatabase, $ConversationsDbTable,
          ConversationsDbData>
    ),
    ConversationsDbData,
    PrefetchHooks Function()>;

class $ConversationDatabaseManager {
  final _$ConversationDatabase _db;
  $ConversationDatabaseManager(this._db);
  $$ConversationsDbTableTableManager get conversationsDb =>
      $$ConversationsDbTableTableManager(_db, _db.conversationsDb);
}
