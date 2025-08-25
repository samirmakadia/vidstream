import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:vidstream/storage/message_storage_drift.dart';
import '../models/api_models.dart';

part 'conversation_storage_drift.g.dart';

class ConversationsDb extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get participants => text()(); // JSON array
  TextColumn get lastMessage => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get deletedFor => text().nullable()(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ConversationsDb])
class ConversationDatabase extends _$ConversationDatabase {
  ConversationDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  //Insert or update a conversation
  Future<void> addOrUpdateConversation(Conversation conversation) async {
    await into(conversationsDb).insertOnConflictUpdate(ConversationsDbCompanion(
      id: Value(conversation.id),
      participants: Value(jsonEncode(conversation.participants)),
      lastMessage: Value(conversation.lastMessage?.id),
      unreadCount: Value(conversation.unreadCount),
      createdAt: Value(conversation.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(conversation.updatedAt.millisecondsSinceEpoch),
      deletedFor: Value(jsonEncode(conversation.deletedFor)),
    ));
  }

  /// Delete all conversations and add new ones from a list
  Future<void> replaceAllConversations(List<Conversation> conversations) async {
    // Delete all existing conversations
    await delete(conversationsDb).go();

    // Insert new conversations
    for (final conversation in conversations) {
      await addOrUpdateConversation(conversation);
    }
  }

  /// Get a single conversation by conversationId
  Future<Conversation?> getConversationById(String conversationId) async {
    final row = await (select(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
    ).getSingleOrNull();

    if (row == null) return null;

    final participantsJson = (jsonDecode(row.participants) as List);
    final participants = participantsJson
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final lastMsg = row.lastMessage != null
        ? await MessageDatabase().getLastMessageByConversationId(row.id)
        : null;

    return Conversation(
      id: row.id,
      conversationId: row.conversationId,
      participants: participants,
      lastMessage: lastMsg,
      unreadCount: row.unreadCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  // Get all conversations, filtering out those deleted for the current user
  Future<List<Conversation>> getAllConversations(String currentUserId) async {
    final rows = await (select(conversationsDb)..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();

    final filteredRows = rows.where((row) {
      if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
        final deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
        return !deletedForList.contains(currentUserId);
      }
      return true;
    });

    final list = await Future.wait(filteredRows.map((row) async {
      final participantsJson = (jsonDecode(row.participants) as List);
      final participants = participantsJson
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final lastMsg = row.lastMessage != null
          ? await MessageDatabase().getLastMessageByConversationId(row.id)
          : null;

      return Conversation(
        id: row.id,
        conversationId: row.conversationId,
        participants: participants,
        lastMessage: lastMsg,
        unreadCount: row.unreadCount,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
    }).toList());

    return list;
  }

    // Watch all conversations as a stream, filtering out those deleted for the current user
  Stream<List<Conversation>> watchAllConversations(String currentUserId) {
    final query = (select(conversationsDb)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
    );
    return query.watch().map((rows) => rows.where((row) {
      // Filter out conversations deleted for this user
      if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
        final deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
        return !deletedForList.contains(currentUserId);
      }
      return true;
    }).map((row) => Conversation(
      id: row.id,
      conversationId: row.conversationId,
      participants: List<ApiUser>.from(jsonDecode(row.participants)),
      lastMessage: null,
      unreadCount: row.unreadCount,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    )).toList());
  }

  // Mark a conversation as deleted for a specific user
  Future<void> deleteConversationForUser(String conversationId, String userId) async {
    final row = await (select(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
    ).getSingleOrNull();

    if (row == null) return;

    // Parse existing deletedFor list
    List<String> deletedForList = [];
    if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
      deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
    }

    // Add userId if not already present
    if (!deletedForList.contains(userId)) {
      deletedForList.add(userId);
    }

    await (update(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
    ).write(ConversationsDbCompanion(
      deletedFor: Value(jsonEncode(deletedForList)),
    ));
  }
}
