import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/api_models.dart';

class ChatStorage {
  static final ChatStorage _instance = ChatStorage._internal();
  factory ChatStorage() => _instance;
  ChatStorage._internal();

  Database? _database;
  static const String _dbName = 'vidstream_chat.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        message_type TEXT NOT NULL,
        content TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        is_deleted INTEGER DEFAULT 0,
        deleted_for TEXT
      )
    ''');

    // Conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        participants TEXT NOT NULL,
        last_message_id TEXT,
        last_message_time INTEGER,
        unread_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // Users table for caching
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        display_name TEXT,
        profile_image_url TEXT,
        data TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_messages_conversation_id ON messages(conversation_id)');
    await db.execute('CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC)');
    await db.execute('CREATE INDEX idx_messages_temp_id ON messages(temp_id)');
    await db.execute('CREATE INDEX idx_conversations_updated_at ON conversations(updated_at DESC)');
    await db.execute('CREATE INDEX idx_users_updated_at ON users(updated_at)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < newVersion) {
      // Add migration logic for future versions
    }
  }

  /// Add or update a message in the database
  Future<void> addOrUpdateMessage(Message message) async {
    final db = await database;
    try {
      final count = await db.update(
        'messages',
        {
          'conversation_id': message.conversationId,
          'sender_id': message.senderId,
          'message_type': message.messageType,
          'content': jsonEncode(message.content.toJson()),
          'status': message.status.name,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'is_deleted': message.isDeleted ? 1 : 0,
          'deleted_for': jsonEncode(message.deletedFor),
        },
        where: 'id = ?',
        whereArgs: [message.id],
      );
      if (count == 0) {
        await db.insert(
          'messages',
          {
            'id': message.id,
            'conversation_id': message.conversationId,
            'sender_id': message.senderId,
            'message_type': message.messageType,
            'content': jsonEncode(message.content.toJson()),
            'status': message.status.name,
            'timestamp': message.timestamp.millisecondsSinceEpoch,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'is_deleted': message.isDeleted ? 1 : 0,
            'deleted_for': jsonEncode(message.deletedFor),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Error addOrUpdateMessage: $e');
    }
  }

  Future<List<Message>> getMessagesForConversation(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );
      
      return maps.map((map) => _messageFromMap(map)).toList().reversed.toList();
    } catch (e) {
      debugPrint('Error getting messages for conversation: $e');
      return [];
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    
    try {
      await db.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  // Conversation operations
  Future<void> saveConversation(Conversation conversation) async {
    // final db = await database;
    //
    // try {
    //   await db.insert(
    //     'conversations',
    //     {
    //       'id': conversation.id,
    //       'participants': jsonEncode(conversation.participants),
    //       'last_message_id': conversation.lastMessage?.id,
    //       'last_message_time': conversation.lastMessageTime?.millisecondsSinceEpoch,
    //       'unread_count': conversation.unreadCount,
    //       'created_at': conversation.createdAt.millisecondsSinceEpoch,
    //       'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
    //       'is_deleted': 0,
    //     },
    //     conflictAlgorithm: ConflictAlgorithm.replace,
    //   );
    // } catch (e) {
    //   debugPrint('Error saving conversation: $e');
    // }
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'conversations',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [conversationId],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        return await _conversationFromMap(maps.first);
      }
    } catch (e) {
      debugPrint('Error getting conversation by ID: $e');
    }
    
    return null;
  }

  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'conversations',
        where: 'is_deleted = 0',
        orderBy: 'updated_at DESC',
      );
      
      final List<Conversation> conversations = [];
      for (final map in maps) {
        final conversation = await _conversationFromMap(map);
        if (conversation != null) {
          conversations.add(conversation);
        }
      }
      
      return conversations;
    } catch (e) {
      debugPrint('Error getting all conversations: $e');
      return [];
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    
    try {
      await db.update(
        'conversations',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  Future<void> restoreConversation(String conversationId) async {
    final db = await database;
    
    try {
      await db.update(
        'conversations',
        {'is_deleted': 0},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    } catch (e) {
      debugPrint('Error restoring conversation: $e');
    }
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final db = await database;
    
    try {
      await db.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      
      // Update conversation to clear last message
      await db.update(
        'conversations',
        {
          'last_message_id': null,
          'last_message_time': null,
          'unread_count': 0,
        },
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    } catch (e) {
      debugPrint('Error clearing conversation messages: $e');
    }
  }

  // User caching operations
  Future<void> cacheUser(ApiUser user) async {
    final db = await database;
    
    try {
      await db.insert(
        'users',
        {
          'id': user.id,
          'email': user.email,
          'display_name': user.displayName,
          'profile_image_url': user.profileImageUrl,
          'data': jsonEncode(user.toJson()),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error caching user: $e');
    }
  }

  Future<ApiUser?> getCachedUser(String userId) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (maps.isNotEmpty) {
        final userData = jsonDecode(maps.first['data'] as String);
        return ApiUser.fromJson(userData);
      }
    } catch (e) {
      debugPrint('Error getting cached user: $e');
    }
    
    return null;
  }

  // Sync operations
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_sync_timestamp');
      return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
        : null;
    } catch (e) {
      debugPrint('Error getting last sync timestamp: $e');
      return null;
    }
  }

  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync_timestamp', timestamp.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error setting last sync timestamp: $e');
    }
  }

  // Auth operations
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  Future<String> getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_user_id') ?? '';
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return '';
    }
  }

  // Helper methods
  Message _messageFromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      messageType: map['message_type'] as String,
      content: MessageContent.fromJson(jsonDecode(map['content'] as String)),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
      deletedFor: map['deleted_for'] != null
        ? List<String>.from(jsonDecode(map['deleted_for'] as String))
        : [],
    );
  }

  Future<Conversation?> _conversationFromMap(Map<String, dynamic> map) async {
    // try {
    //   Message? lastMessage;
    //   if (map['last_message_id'] != null) {
    //     // lastMessage = await getMessageById(map['last_message_id'] as String);
    //   }
    //
    //   return Conversation(
    //     id: map['id'] as String,
    //     participants: List<String>.from(jsonDecode(map['participants'] as String)),
    //     lastMessage: lastMessage,
    //     lastMessageTime: map['last_message_time'] != null
    //       ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'] as int)
    //       : null,
    //     unreadCount: map['unread_count'] as int? ?? 0,
    //     createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    //     updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    //   );
    // } catch (e) {
    //   debugPrint('Error converting conversation from map: $e');
    //   return null;
    // }
  }

  // Cleanup operations
  Future<void> clearAllData() async {
    final db = await database;
    
    try {
      await db.delete('messages');
      await db.delete('conversations');
      await db.delete('users');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_timestamp');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }

  // Initialize method for compatibility
  Future<void> initialize() async {
    // Database is initialized lazily through the getter
    await database;
  }

  // Add message method for compatibility with old interface
  Future<void> addMessage(Message message) async {
    // await saveMessage(message);
  }

  // Get messages method for compatibility
  Future<List<Message>> getMessages(String conversationId) async {
    return getMessagesForConversation(conversationId);
  }

  // Cache messages method for batch operations
  Future<void> cacheMessages(List<Message> messages) async {
    final db = await database;
    final batch = db.batch();
    
    try {
      for (final message in messages) {
        batch.insert(
          'messages',
          {
            'id': message.id,
            'conversation_id': message.conversationId,
            'sender_id': message.senderId,
            'message_type': message.messageType,
            'content': jsonEncode(message.content.toJson()),
            'status': message.status.name,
            'timestamp': message.timestamp.millisecondsSinceEpoch,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'is_deleted': message.isDeleted ? 1 : 0,
            'deleted_for': jsonEncode(message.deletedFor),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Error caching messages: $e');
    }
  }

  // Get conversations method for compatibility
  Future<List<Conversation>> getConversations() async {
    return getAllConversations();
  }

  // Cache conversations method for batch operations
  Future<void> cacheConversations(List<Conversation> conversations) async {
    // final db = await database;
    // final batch = db.batch();
    //
    // try {
    //   for (final conversation in conversations) {
    //     batch.insert(
    //       'conversations',
    //       {
    //         'id': conversation.id,
    //         'participants': jsonEncode(conversation.participants),
    //         'last_message_id': conversation.lastMessage?.id,
    //         'last_message_time': conversation.lastMessageTime?.millisecondsSinceEpoch,
    //         'unread_count': conversation.unreadCount,
    //         'created_at': conversation.createdAt.millisecondsSinceEpoch,
    //         'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
    //         'is_deleted': 0,
    //       },
    //       conflictAlgorithm: ConflictAlgorithm.replace,
    //     );
    //   }
    //
    //   await batch.commit(noResult: true);
    // } catch (e) {
    //   debugPrint('Error caching conversations: $e');
    // }
  }
}