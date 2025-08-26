import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:vidstream/storage/message_storage_drift.dart';
import '../models/api_models.dart';
import '../services/chat_service.dart';

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
  // --- singleton setup ---
  ConversationDatabase._internal() : super(NativeDatabase.memory());
  static final ConversationDatabase instance = ConversationDatabase._internal();

  @override
  int get schemaVersion => 1;


  //Insert or update a conversation
  Future<void> addOrUpdateConversation(Conversation conversation) async {
    await into(conversationsDb).insertOnConflictUpdate(
      ConversationsDbCompanion(
        id: Value(conversation.id),
        conversationId: Value(conversation.conversationId),
        participants: Value(jsonEncode(conversation.participants)),
        lastMessage: Value(conversation.lastMessage?.id),
        unreadCount: Value(conversation.unreadCount),
        createdAt: Value(conversation.createdAt.millisecondsSinceEpoch),
        updatedAt: Value(conversation.updatedAt.millisecondsSinceEpoch),
        deletedFor: Value(jsonEncode(conversation.deletedFor)),
      ),
    );
  }

  Future<void> replaceAllConversations(List<Conversation> conversations) async {
    await delete(conversationsDb).go();
    for (final conversation in conversations) {
      await addOrUpdateConversation(conversation);
    }
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    final row = await (select(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .getSingleOrNull();

    if (row == null) return null;

    final participants = (jsonDecode(row.participants) as List)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final lastMsg = row.lastMessage != null
        ? await MessageDatabase.instance.getLastMessageByConversationId(row.id)
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

  Future<List<Conversation>> getAllConversations(String currentUserId) async {
    final rows = await (select(conversationsDb)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();

    final filtered = rows.where((row) {
      if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
        final deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
        return !deletedForList.contains(currentUserId);
      }
      return true;
    });

    return Future.wait(filtered.map((row) async {
      final participants = (jsonDecode(row.participants) as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final lastMsg = row.lastMessage != null
          ? await MessageDatabase.instance
          .getLastMessageByConversationId(row.id)
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
    }));
  }

  // Stream<List<Conversation>> watchAllConversations(String currentUserId) {
  //   final query = (select(conversationsDb)
  //     ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]));
  //
  //   return query.watch().map((rows) {
  //     return rows.where((row) {
  //       if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
  //         final deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
  //         return !deletedForList.contains(currentUserId);
  //       }
  //       return true;
  //     }).map((row) {
  //       final participants = (jsonDecode(row.participants) as List)
  //           .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
  //           .toList();
  //
  //       final lastMsg = row.lastMessage != null
  //           ? await MessageDatabase.instance.getLastMessageByConversationId(row.id)
  //           : null;
  //       return Conversation(
  //         id: row.id,
  //         conversationId: row.conversationId,
  //         participants: participants,
  //         lastMessage: , // can be populated if needed
  //         unreadCount: row.unreadCount,
  //         createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  //         updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  //       );
  //     }).toList();
  //   });
  // }

  Stream<List<Conversation>> watchAllConversations(String currentUserId) {
    final query = (select(conversationsDb)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]));

    return query.watch().asyncMap((rows) async {
      // 1) Filter out conversations deleted for this user
      final filtered = rows.where((row) {
        final df = row.deletedFor;
        if (df == null || df.isEmpty) return true;
        try {
          final list = (jsonDecode(df) as List).cast<String>();
          return !list.contains(currentUserId);
        } catch (_) {
          // If malformed JSON, keep the conversation instead of crashing
          return true;
        }
      }).toList();

      // 2) Decode participants
      List<List<AppUser>> participantsPerRow = filtered.map((row) {
        final raw = jsonDecode(row.participants) as List;
        return raw.map((e) {
          final map = (e is Map<String, dynamic>) ? e : Map<String, dynamic>.from(e as Map);
          return AppUser.fromJson(map);
        }).toList();
      }).toList();

      // 3) Get last messages in parallel (only if you really need them here)
      final lastMsgs = await Future.wait(filtered.map((row) async {
        // If you gate this with some flag/column, keep it; otherwise just fetch.
        return MessageDatabase.instance.getLastMessageByConversationId(row.id);
      }));

      // 4) Build domain objects
      final conversations = <Conversation>[];
      for (int i = 0; i < filtered.length; i++) {
        final row = filtered[i];
        conversations.add(
          Conversation(
            id: row.id,
            conversationId: row.conversationId,
            participants: participantsPerRow[i],
            lastMessage: lastMsgs[i], // Message? nullable, as your model defines
            unreadCount: row.unreadCount ?? 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
          ),
        );
      }

      return conversations;
    });
  }

  Future<void> deleteConversationForUser(
      String conversationId, String userId) async {
    final row = await (select(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .getSingleOrNull();

    if (row == null) return;

    List<String> deletedForList = [];
    if (row.deletedFor != null && row.deletedFor!.isNotEmpty) {
      deletedForList = List<String>.from(jsonDecode(row.deletedFor!));
    }

    if (!deletedForList.contains(userId)) {
      deletedForList.add(userId);
    }

    await (update(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .write(
      ConversationsDbCompanion(
        deletedFor: Value(jsonEncode(deletedForList)),
      ),
    );
  }

  /// Update the lastMessage field by conversationId
  Future<void> updateLastMessageIdByConversationId(String conversationId, String lastMessageId) async {
    var row = await (select(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .getSingleOrNull();

    if (row == null) {
      // Fetch from ChatService if not found locally
      final chatService = ChatService();
      await chatService.fetchAndCacheConversations();
    }

    await (update(conversationsDb)
      ..where((tbl) => tbl.conversationId.equals(conversationId)))
        .write(
      ConversationsDbCompanion(
        lastMessage: Value(lastMessageId),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
