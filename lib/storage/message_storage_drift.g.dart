// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_storage_drift.dart';

// ignore_for_file: type=lint
class $MessagesDbTable extends MessagesDb
    with TableInfo<$MessagesDbTable, MessagesDbData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesDbTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTypeMeta =
      const VerificationMeta('messageType');
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
      'message_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedForMeta =
      const VerificationMeta('deletedFor');
  @override
  late final GeneratedColumn<String> deletedFor = GeneratedColumn<String>(
      'deleted_for', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        messageId,
        conversationId,
        senderId,
        messageType,
        content,
        status,
        timestamp,
        isDeleted,
        deletedFor
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_db';
  @override
  VerificationContext validateIntegrity(Insertable<MessagesDbData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
          _messageTypeMeta,
          messageType.isAcceptableOrUnknown(
              data['message_type']!, _messageTypeMeta));
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
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
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  MessagesDbData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessagesDbData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id']),
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}timestamp'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      deletedFor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deleted_for']),
    );
  }

  @override
  $MessagesDbTable createAlias(String alias) {
    return $MessagesDbTable(attachedDatabase, alias);
  }
}

class MessagesDbData extends DataClass implements Insertable<MessagesDbData> {
  final String? id;
  final String messageId;
  final String conversationId;
  final String senderId;
  final String messageType;
  final String content;
  final String status;
  final int timestamp;
  final bool isDeleted;
  final String? deletedFor;
  const MessagesDbData(
      {this.id,
      required this.messageId,
      required this.conversationId,
      required this.senderId,
      required this.messageType,
      required this.content,
      required this.status,
      required this.timestamp,
      required this.isDeleted,
      this.deletedFor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || id != null) {
      map['id'] = Variable<String>(id);
    }
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['message_type'] = Variable<String>(messageType);
    map['content'] = Variable<String>(content);
    map['status'] = Variable<String>(status);
    map['timestamp'] = Variable<int>(timestamp);
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedFor != null) {
      map['deleted_for'] = Variable<String>(deletedFor);
    }
    return map;
  }

  MessagesDbCompanion toCompanion(bool nullToAbsent) {
    return MessagesDbCompanion(
      id: id == null && nullToAbsent ? const Value.absent() : Value(id),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      messageType: Value(messageType),
      content: Value(content),
      status: Value(status),
      timestamp: Value(timestamp),
      isDeleted: Value(isDeleted),
      deletedFor: deletedFor == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedFor),
    );
  }

  factory MessagesDbData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessagesDbData(
      id: serializer.fromJson<String?>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      messageType: serializer.fromJson<String>(json['messageType']),
      content: serializer.fromJson<String>(json['content']),
      status: serializer.fromJson<String>(json['status']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedFor: serializer.fromJson<String?>(json['deletedFor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String?>(id),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'messageType': serializer.toJson<String>(messageType),
      'content': serializer.toJson<String>(content),
      'status': serializer.toJson<String>(status),
      'timestamp': serializer.toJson<int>(timestamp),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedFor': serializer.toJson<String?>(deletedFor),
    };
  }

  MessagesDbData copyWith(
          {Value<String?> id = const Value.absent(),
          String? messageId,
          String? conversationId,
          String? senderId,
          String? messageType,
          String? content,
          String? status,
          int? timestamp,
          bool? isDeleted,
          Value<String?> deletedFor = const Value.absent()}) =>
      MessagesDbData(
        id: id.present ? id.value : this.id,
        messageId: messageId ?? this.messageId,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        messageType: messageType ?? this.messageType,
        content: content ?? this.content,
        status: status ?? this.status,
        timestamp: timestamp ?? this.timestamp,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedFor: deletedFor.present ? deletedFor.value : this.deletedFor,
      );
  MessagesDbData copyWithCompanion(MessagesDbCompanion data) {
    return MessagesDbData(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      content: data.content.present ? data.content.value : this.content,
      status: data.status.present ? data.status.value : this.status,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedFor:
          data.deletedFor.present ? data.deletedFor.value : this.deletedFor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessagesDbData(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('messageType: $messageType, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('timestamp: $timestamp, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedFor: $deletedFor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, messageId, conversationId, senderId,
      messageType, content, status, timestamp, isDeleted, deletedFor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessagesDbData &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.messageType == this.messageType &&
          other.content == this.content &&
          other.status == this.status &&
          other.timestamp == this.timestamp &&
          other.isDeleted == this.isDeleted &&
          other.deletedFor == this.deletedFor);
}

class MessagesDbCompanion extends UpdateCompanion<MessagesDbData> {
  final Value<String?> id;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> messageType;
  final Value<String> content;
  final Value<String> status;
  final Value<int> timestamp;
  final Value<bool> isDeleted;
  final Value<String?> deletedFor;
  final Value<int> rowid;
  const MessagesDbCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedFor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesDbCompanion.insert({
    this.id = const Value.absent(),
    required String messageId,
    required String conversationId,
    required String senderId,
    required String messageType,
    required String content,
    required String status,
    required int timestamp,
    this.isDeleted = const Value.absent(),
    this.deletedFor = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        conversationId = Value(conversationId),
        senderId = Value(senderId),
        messageType = Value(messageType),
        content = Value(content),
        status = Value(status),
        timestamp = Value(timestamp);
  static Insertable<MessagesDbData> custom({
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? messageType,
    Expression<String>? content,
    Expression<String>? status,
    Expression<int>? timestamp,
    Expression<bool>? isDeleted,
    Expression<String>? deletedFor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (messageType != null) 'message_type': messageType,
      if (content != null) 'content': content,
      if (status != null) 'status': status,
      if (timestamp != null) 'timestamp': timestamp,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedFor != null) 'deleted_for': deletedFor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesDbCompanion copyWith(
      {Value<String?>? id,
      Value<String>? messageId,
      Value<String>? conversationId,
      Value<String>? senderId,
      Value<String>? messageType,
      Value<String>? content,
      Value<String>? status,
      Value<int>? timestamp,
      Value<bool>? isDeleted,
      Value<String?>? deletedFor,
      Value<int>? rowid}) {
    return MessagesDbCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
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
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
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
    return (StringBuffer('MessagesDbCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('messageType: $messageType, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('timestamp: $timestamp, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedFor: $deletedFor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MessageDatabase extends GeneratedDatabase {
  _$MessageDatabase(QueryExecutor e) : super(e);
  $MessageDatabaseManager get managers => $MessageDatabaseManager(this);
  late final $MessagesDbTable messagesDb = $MessagesDbTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [messagesDb];
}

typedef $$MessagesDbTableCreateCompanionBuilder = MessagesDbCompanion Function({
  Value<String?> id,
  required String messageId,
  required String conversationId,
  required String senderId,
  required String messageType,
  required String content,
  required String status,
  required int timestamp,
  Value<bool> isDeleted,
  Value<String?> deletedFor,
  Value<int> rowid,
});
typedef $$MessagesDbTableUpdateCompanionBuilder = MessagesDbCompanion Function({
  Value<String?> id,
  Value<String> messageId,
  Value<String> conversationId,
  Value<String> senderId,
  Value<String> messageType,
  Value<String> content,
  Value<String> status,
  Value<int> timestamp,
  Value<bool> isDeleted,
  Value<String?> deletedFor,
  Value<int> rowid,
});

class $$MessagesDbTableFilterComposer
    extends Composer<_$MessageDatabase, $MessagesDbTable> {
  $$MessagesDbTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => ColumnFilters(column));
}

class $$MessagesDbTableOrderingComposer
    extends Composer<_$MessageDatabase, $MessagesDbTable> {
  $$MessagesDbTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => ColumnOrderings(column));
}

class $$MessagesDbTableAnnotationComposer
    extends Composer<_$MessageDatabase, $MessagesDbTable> {
  $$MessagesDbTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get messageType => $composableBuilder(
      column: $table.messageType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedFor => $composableBuilder(
      column: $table.deletedFor, builder: (column) => column);
}

class $$MessagesDbTableTableManager extends RootTableManager<
    _$MessageDatabase,
    $MessagesDbTable,
    MessagesDbData,
    $$MessagesDbTableFilterComposer,
    $$MessagesDbTableOrderingComposer,
    $$MessagesDbTableAnnotationComposer,
    $$MessagesDbTableCreateCompanionBuilder,
    $$MessagesDbTableUpdateCompanionBuilder,
    (
      MessagesDbData,
      BaseReferences<_$MessageDatabase, $MessagesDbTable, MessagesDbData>
    ),
    MessagesDbData,
    PrefetchHooks Function()> {
  $$MessagesDbTableTableManager(_$MessageDatabase db, $MessagesDbTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesDbTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesDbTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesDbTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String?> id = const Value.absent(),
            Value<String> messageId = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<String> messageType = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> timestamp = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedFor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesDbCompanion(
            id: id,
            messageId: messageId,
            conversationId: conversationId,
            senderId: senderId,
            messageType: messageType,
            content: content,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            deletedFor: deletedFor,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String?> id = const Value.absent(),
            required String messageId,
            required String conversationId,
            required String senderId,
            required String messageType,
            required String content,
            required String status,
            required int timestamp,
            Value<bool> isDeleted = const Value.absent(),
            Value<String?> deletedFor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesDbCompanion.insert(
            id: id,
            messageId: messageId,
            conversationId: conversationId,
            senderId: senderId,
            messageType: messageType,
            content: content,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            deletedFor: deletedFor,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesDbTableProcessedTableManager = ProcessedTableManager<
    _$MessageDatabase,
    $MessagesDbTable,
    MessagesDbData,
    $$MessagesDbTableFilterComposer,
    $$MessagesDbTableOrderingComposer,
    $$MessagesDbTableAnnotationComposer,
    $$MessagesDbTableCreateCompanionBuilder,
    $$MessagesDbTableUpdateCompanionBuilder,
    (
      MessagesDbData,
      BaseReferences<_$MessageDatabase, $MessagesDbTable, MessagesDbData>
    ),
    MessagesDbData,
    PrefetchHooks Function()>;

class $MessageDatabaseManager {
  final _$MessageDatabase _db;
  $MessageDatabaseManager(this._db);
  $$MessagesDbTableTableManager get messagesDb =>
      $$MessagesDbTableTableManager(_db, _db.messagesDb);
}
