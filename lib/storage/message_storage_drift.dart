import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../models/api_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
part 'message_storage_drift.g.dart';

class MessagesDb extends Table {
  TextColumn get id => text().nullable()();
  TextColumn get messageId => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get messageType => text()();
  TextColumn get content => text()();
  TextColumn get status => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deletedFor => text().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [MessagesDb])
class MessageDatabase extends _$MessageDatabase {
  // private constructor
  MessageDatabase._internal() : super(openConnection());

  static MessageDatabase? _instance;
  static MessageDatabase get instance =>
      _instance ??= MessageDatabase._internal();


  @override
  int get schemaVersion => 1;

  // Insert or update a message
  Future<void> addOrUpdateMessage(MessageModel message) async {
    final nowIso = DateTime.now().toIso8601String();

    await into(messagesDb).insertOnConflictUpdate(MessagesDbCompanion(
      id: Value(message.id),
      messageId: Value(message.messageId),
      conversationId: Value(message.conversationId),
      senderId: Value(message.senderId),
      messageType: Value(message.messageType),
      content: Value(jsonEncode(message.content.toJson())),
      status: Value(message.status.name),
      createdAt: Value(message.createdAt.isNotEmpty ? message.createdAt : nowIso),
      updatedAt: Value(message.updatedAt.isNotEmpty ? message.updatedAt : nowIso),
      isDeleted: Value(message.isDeleted),
      deletedFor: Value(jsonEncode(message.deletedFor)),
    ));
  }


  /// Get the last message for a conversation
  Future<MessageModel?> getLastMessageByConversationId(String conversationId) async {
    final row = await (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(1)
    ).getSingleOrNull();

    if (row == null) return null;

    return MessageModel(
      id: row.id,
      messageId: row.messageId,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere((e) => e.name == row.status, orElse: () => MessageStatus.sent),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null ? List<String>.from(jsonDecode(row.deletedFor!)) : [],
    );
  }

  //Get messages for a conversation
  Future<List<MessageModel>> getMessagesForConversation(String conversationId, {int limit = 50, int offset = 0}) async {
    final rows = await (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(limit, offset: offset)
    ).get();

    return rows.map((row) => MessageModel(
      id: row.id,
      messageId: row.messageId,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere((e) => e.name == row.status, orElse: () => MessageStatus.sent),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null ? List<String>.from(jsonDecode(row.deletedFor!)) : [],
    )).toList().reversed.toList();
  }

  // Watch messages for a conversation as a stream
  Stream<List<MessageModel>> watchMessagesForConversation(String conversationId, {int limit = 50, int offset = 0}) {
    final query = (select(messagesDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(limit, offset: offset)
    );

    return query.watch().map((rows) => rows.map((row) => MessageModel(
      id: row.id,
      messageId: row.messageId,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere(
              (e) => e.name == row.status,
          orElse: () => MessageStatus.sent),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null
          ? List<String>.from(jsonDecode(row.deletedFor!))
          : [],
    )).toList());
  }


  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    await (delete(messagesDb)..where((tbl) => tbl.messageId.equals(messageId))).go();
  }

  Future<void> deleteMessageById(String messageId) async {
    await (delete(messagesDb)..where((tbl) => tbl.messageId.equals(messageId))).go();
    print("🗑️ Deleted message locally: $messageId");
  }

  /// Delete all messages by conversationId
  Future<void> deleteMessagesByConversationId(String conversationId) async {
    await (delete(messagesDb)..where((tbl) => tbl.conversationId.equals(conversationId))).go();
    print("🗑️ Deleted all messages for conversation: $conversationId");
  }

  /// Clear the entire messages table
  Future<void> clearMessagesTable() async {
    await delete(messagesDb).go();
    print("🧹 Cleared all messages from the table");
  }

  Stream<int> watchUnreadCount(String conversationId, String currentUserId) {
    final query = select(messagesDb)
      ..where((tbl) =>
      tbl.conversationId.equals(conversationId) &
      tbl.senderId.isNotValue(currentUserId) &
      tbl.status.isNotValue("read"));

    return query.watch().map((rows) => rows.length);
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    await (update(messagesDb)
      ..where((tbl) => tbl.messageId.equals(messageId)))
        .write(MessagesDbCompanion(
      status: Value(status),
    ));

    print("✅ Message $messageId status updated to $status");
  }

  Future<List<MessageModel>> getMessagesByStatus(String status) async {
    final rows = await (select(messagesDb)
      ..where((tbl) => tbl.status.equals(status))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])
    ).get();

    return rows.map((row) => MessageModel(
      id: row.id,
      messageId: row.messageId,
      conversationId: row.conversationId,
      senderId: row.senderId,
      messageType: row.messageType,
      content: MessageContent.fromJson(jsonDecode(row.content)),
      status: MessageStatus.values.firstWhere(
              (e) => e.name == row.status,
          orElse: () => MessageStatus.sent),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
      deletedFor: row.deletedFor != null
          ? List<String>.from(jsonDecode(row.deletedFor!))
          : [],
    )).toList();
  }

}
