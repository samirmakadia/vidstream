import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../models/api_models.dart';
part 'message_storage_drift.g.dart';

class MessagesDb extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get messageType => text()();
  TextColumn get content => text()(); // JSON string
  TextColumn get status => text()();
  IntColumn get timestamp => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedFor => text().nullable()(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [MessagesDb])
class MessageDatabase extends _$MessageDatabase {
  // private constructor
  MessageDatabase._internal() : super(NativeDatabase.memory());

  static MessageDatabase? _instance;
  static MessageDatabase get instance =>
      _instance ??= MessageDatabase._internal();


  @override
  int get schemaVersion => 1;

  // Insert or update a message
  Future<void> addOrUpdateMessage(Message message) async {
    await into(messagesDb).insertOnConflictUpdate(MessagesDbCompanion(
      id: Value(message.id),
      conversationId: Value(message.conversationId),
      senderId: Value(message.senderId),
      messageType: Value(message.messageType),
      content: Value(jsonEncode(message.content.toJson())),
      status: Value(message.status.name),
      timestamp: Value(message.timestamp.millisecondsSinceEpoch),
      isDeleted: Value(message.isDeleted),
      deletedFor: Value(jsonEncode(message.deletedFor)),
    ));
  }

  /// Get the last message for a conversation
  Future<Message?> getLastMessageByConversationId(String conversationId) async {
    final row = await (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(1)
    ).getSingleOrNull();

    if (row == null) return null;

    return Message(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere((e) => e.name == row.status, orElse: () => MessageStatus.sent),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null ? List<String>.from(jsonDecode(row.deletedFor!)) : [],
    );
  }

  //Get messages for a conversation
  Future<List<Message>> getMessagesForConversation(String conversationId, {int limit = 50, int offset = 0}) async {
    final rows = await (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit, offset: offset)
    ).get();

    return rows.map((row) => Message(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere((e) => e.name == row.status, orElse: () => MessageStatus.sent),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null ? List<String>.from(jsonDecode(row.deletedFor!)) : [],
    )).toList().reversed.toList();
  }

  // Watch messages for a conversation as a stream
  Stream<List<Message>> watchMessagesForConversation(String conversationId, {int limit = 50, int offset = 0}) {
    final query = (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
      ..limit(limit, offset: offset)
    );
    return query.watch().map((rows) => rows.map((row) => Message(
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere((e) => e.name == row.status, orElse: () => MessageStatus.sent),
      timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null ? List<String>.from(jsonDecode(row.deletedFor!)) : [],
    )).toList().reversed.toList());
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    await (delete(messagesDb)..where((tbl) => tbl.id.equals(messageId))).go();
  }
}
