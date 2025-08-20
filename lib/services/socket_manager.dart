import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/api_models.dart';
import '../storage/chat_storage.dart';
import '../utils/connectivity_service.dart';
import '../services/http_client.dart';

enum SocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error
}

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;
  SocketManager._internal();

  IO.Socket? _socket;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  // Status tracking
  SocketStatus _status = SocketStatus.disconnected;
  bool _isManualDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  
  // Message queue for offline/pending messages
  final List<Map<String, dynamic>> _pendingMessages = [];
  final Set<String> _pendingMessageIds = {};
  
  // Storage and connectivity
  late ChatStorage _chatStorage;
  late ConnectivityService _connectivityService;
  late HttpClient _httpClient;
  
  // Stream controllers for reactive updates
  final StreamController<SocketStatus> _statusController = 
      StreamController<SocketStatus>.broadcast();
  final StreamController<Message> _messageController = 
      StreamController<Message>.broadcast();
  final StreamController<Message> _messageUpdateController = 
      StreamController<Message>.broadcast();
  final StreamController<Conversation> _conversationController = 
      StreamController<Conversation>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationDeleteController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<SocketStatus> get statusStream => _statusController.stream;
  Stream<Message> get messageStream => _messageController.stream;
  Stream<Message> get messageUpdateStream => _messageUpdateController.stream;
  Stream<Conversation> get conversationStream => _conversationController.stream;
  Stream<Map<String, dynamic>> get conversationDeleteStream => _conversationDeleteController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  
  SocketStatus get status => _status;
  bool get isConnected => _status == SocketStatus.connected;

  /// Initialize socket manager with dependencies
  Future<void> initialize({
    required ChatStorage chatStorage,
    required ConnectivityService connectivityService,
    required HttpClient httpClient,
  }) async {
    try {
      _chatStorage = chatStorage;
      _connectivityService = connectivityService;
      _httpClient = httpClient;
      
      // Listen to connectivity changes (but don't auto-connect)
      _connectivityService.connectivityStream.listen((isConnected) {
        debugPrint('Connectivity changed: $isConnected');
        // Only reconnect if we were previously connected and disconnected due to network issues
        if (isConnected && _status == SocketStatus.error && !_isManualDisconnect) {
          debugPrint('Attempting to reconnect socket...');
          connect().catchError((e) => debugPrint('Reconnect failed: $e'));
        }
      });
      
      debugPrint('✅ SocketManager initialized (no auto-connect)');
    } catch (e) {
      debugPrint('❌ SocketManager init error: $e');
      rethrow;
    }
  }

  /// Connect to socket server
  Future<void> connect({String? token}) async {
    if (_status == SocketStatus.connected || _status == SocketStatus.connecting) {
      return;
    }

    _isManualDisconnect = false;
    _updateStatus(SocketStatus.connecting);

    try {
      final authToken = token ?? await _getStoredToken();
      if (authToken == null) {
        throw Exception('No authentication token available');
      }

      _socket = IO.io('https://collie-humorous-goose.ngrok-free.app', 
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setAuth({
            'token': authToken,
          })
          .build()
      );

      _setupSocketListeners();
      
    } catch (e) {
      debugPrint('Socket connection failed: $e');
      _updateStatus(SocketStatus.error);
      _scheduleReconnect();
    }
  }

  /// Setup all socket event listeners
  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      debugPrint('Socket connected successfully');
      _updateStatus(SocketStatus.connected);
      _reconnectAttempts = 0;
      _startPingTimer();
      _processPendingMessages();
      _syncMessagesFromServer();
    });

    _socket?.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _updateStatus(SocketStatus.disconnected);
      _stopPingTimer();
      
      if (!_isManualDisconnect) {
        _scheduleReconnect();
      }
    });

    _socket?.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _updateStatus(SocketStatus.error);
      _scheduleReconnect();
    });

    _socket?.onReconnectError((error) {
      debugPrint('Socket reconnection error: $error');
      _reconnectAttempts++;
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        _updateStatus(SocketStatus.error);
      }
    });

    // Message events
    _socket?.on('message', _handleNewMessage);
    _socket?.on('message_delivered', _handleMessageDelivered);
    _socket?.on('message_read', _handleMessageRead);
    _socket?.on('message_updated', _handleMessageUpdated);
    _socket?.on('message_deleted', _handleMessageDeleted);

    // Conversation events
    _socket?.on('conversation_updated', _handleConversationUpdated);
    _socket?.on('conversation_deleted', _handleConversationDeleted);
    _socket?.on('conversation_cleared', _handleConversationCleared);
    _socket?.on('conversation_restored', _handleConversationRestored);

    // Presence events
    _socket?.on('user_online', _handleUserOnline);
    _socket?.on('user_offline', _handleUserOffline);
    _socket?.on('typing_start', _handleTypingStart);
    _socket?.on('typing_stop', _handleTypingStop);

    // Sync events
    _socket?.on('sync_messages', _handleSyncMessages);
    _socket?.on('sync_conversations', _handleSyncConversations);

    // Error events
    _socket?.on('error', (error) {
      debugPrint('Socket error: $error');
    });
  }

  /// Send message through socket and store locally
  Future<Message> sendMessage({
    required String conversationId,
    required String messageType,
    required Map<String, dynamic> content,
    String? replyToId,
  }) async {
    // Create optimistic message for immediate UI update
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final message = Message(
      id: tempId,
      conversationId: conversationId,
      senderId: await _getCurrentUserId(),
      messageType: messageType,
      content: content,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      tempId: tempId,
    );

    // Store in local database immediately
    await _chatStorage.saveMessage(message);
    _messageController.add(message);

    // Prepare socket message
    final socketMessage = {
      'tempId': tempId,
      'conversationId': conversationId,
      'messageType': messageType,
      'content': content,
      'replyToId': replyToId,
      'timestamp': message.timestamp.toIso8601String(),
    };

    if (isConnected) {
      _socket?.emit('send_message', socketMessage);
    } else {
      // Add to pending queue if offline
      _pendingMessages.add(socketMessage);
      _pendingMessageIds.add(tempId);
      
      // Update message status to pending
      final pendingMessage = message.copyWith(status: MessageStatus.pending);
      await _chatStorage.updateMessage(pendingMessage);
      _messageUpdateController.add(pendingMessage);
    }

    return message;
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    // Update local storage first
    await _chatStorage.markMessagesAsRead(conversationId, messageIds);
    
    // Emit to server
    if (isConnected) {
      _socket?.emit('mark_messages_read', {
        'conversationId': conversationId,
        'messageIds': messageIds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Start typing indicator
  void startTyping(String conversationId) {
    if (isConnected) {
      _socket?.emit('typing_start', {
        'conversationId': conversationId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Stop typing indicator
  void stopTyping(String conversationId) {
    if (isConnected) {
      _socket?.emit('typing_stop', {
        'conversationId': conversationId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Update user presence
  void updatePresence({required bool isOnline}) {
    if (isConnected) {
      _socket?.emit('update_presence', {
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Process pending messages when connection is restored
  Future<void> _processPendingMessages() async {
    if (_pendingMessages.isEmpty) return;

    debugPrint('Processing ${_pendingMessages.length} pending messages');
    
    final messagesToProcess = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final messageData in messagesToProcess) {
      _socket?.emit('send_message', messageData);
      _pendingMessageIds.remove(messageData['tempId']);
    }
  }

  /// Sync messages from server based on last seen timestamp
  Future<void> _syncMessagesFromServer() async {
    try {
      final lastSyncTime = await _chatStorage.getLastSyncTimestamp();
      
      _socket?.emit('sync_request', {
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'type': 'messages',
      });

      // Also sync conversations
      _socket?.emit('sync_request', {
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'type': 'conversations',
      });
      
    } catch (e) {
      debugPrint('Error syncing messages: $e');
    }
  }

  /// Handle new message received from server
  void _handleNewMessage(dynamic data) async {
    try {
      final message = Message.fromJson(data);
      
      // Store in local database
      await _chatStorage.saveMessage(message);
      
      // Emit to UI
      _messageController.add(message);
      
      // Update conversation last message
      await _updateConversationLastMessage(message);
      
    } catch (e) {
      debugPrint('Error handling new message: $e');
    }
  }

  /// Handle message delivery confirmation
  void _handleMessageDelivered(dynamic data) async {
    try {
      final messageId = data['messageId'] as String;
      final tempId = data['tempId'] as String?;
      
      Message? message;
      
      if (tempId != null) {
        // This is a confirmation for our sent message
        message = await _chatStorage.getMessageByTempId(tempId);
        if (message != null) {
          // Update with server-assigned ID and delivered status
          final updatedMessage = message.copyWith(
            id: messageId,
            status: MessageStatus.delivered,
          );
          await _chatStorage.updateMessage(updatedMessage);
          _messageUpdateController.add(updatedMessage);
        }
      } else {
        // This is a delivery update for existing message
        message = await _chatStorage.getMessageById(messageId);
        if (message != null) {
          final updatedMessage = message.copyWith(status: MessageStatus.delivered);
          await _chatStorage.updateMessage(updatedMessage);
          _messageUpdateController.add(updatedMessage);
        }
      }
    } catch (e) {
      debugPrint('Error handling message delivered: $e');
    }
  }

  /// Handle message read confirmation
  void _handleMessageRead(dynamic data) async {
    try {
      final messageIds = List<String>.from(data['messageIds']);
      final readBy = data['readBy'] as String;
      final timestamp = DateTime.parse(data['timestamp']);
      
      for (final messageId in messageIds) {
        final message = await _chatStorage.getMessageById(messageId);
        if (message != null) {
          final updatedMessage = message.copyWith(
            status: MessageStatus.read,
            readAt: timestamp,
          );
          await _chatStorage.updateMessage(updatedMessage);
          _messageUpdateController.add(updatedMessage);
        }
      }
    } catch (e) {
      debugPrint('Error handling message read: $e');
    }
  }

  /// Handle message update
  void _handleMessageUpdated(dynamic data) async {
    try {
      final updatedMessage = Message.fromJson(data);
      await _chatStorage.updateMessage(updatedMessage);
      _messageUpdateController.add(updatedMessage);
    } catch (e) {
      debugPrint('Error handling message updated: $e');
    }
  }

  /// Handle message deletion
  void _handleMessageDeleted(dynamic data) async {
    try {
      final messageId = data['messageId'] as String;
      await _chatStorage.deleteMessage(messageId);
      
      // Emit deletion event
      _messageUpdateController.add(
        Message(
          id: messageId,
          conversationId: '',
          senderId: '',
          messageType: 'deleted',
          content: {},
          status: MessageStatus.deleted,
          timestamp: DateTime.now(),
        )
      );
    } catch (e) {
      debugPrint('Error handling message deleted: $e');
    }
  }

  /// Handle conversation updates
  void _handleConversationUpdated(dynamic data) async {
    try {
      final conversation = Conversation.fromJson(data);
      await _chatStorage.saveConversation(conversation);
      _conversationController.add(conversation);
    } catch (e) {
      debugPrint('Error handling conversation updated: $e');
    }
  }

  /// Handle conversation deletion
  void _handleConversationDeleted(dynamic data) async {
    try {
      final conversationId = data['conversationId'] as String;
      await _chatStorage.deleteConversation(conversationId);
      
      // Emit deletion event
      _conversationDeleteController.add({
        'type': 'deleted',
        'conversationId': conversationId,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error handling conversation deleted: $e');
    }
  }

  /// Handle conversation cleared (all messages deleted)
  void _handleConversationCleared(dynamic data) async {
    try {
      final conversationId = data['conversationId'] as String;
      await _chatStorage.clearConversationMessages(conversationId);
      
      // Emit cleared event
      _conversationDeleteController.add({
        'type': 'cleared',
        'conversationId': conversationId,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error handling conversation cleared: $e');
    }
  }

  /// Handle conversation restored (when new message is sent after deletion)
  void _handleConversationRestored(dynamic data) async {
    try {
      final conversationId = data['conversationId'] as String;
      final restoredBy = data['restoredBy'] as String;

      // Remove conversation from deleted list in local storage
      await _chatStorage.restoreConversation(conversationId);

      // Emit to UI
      _conversationDeleteController.add({
        'type': 'restored',
        'conversationId': conversationId,
        'restoredBy': restoredBy,
        'timestamp': DateTime.now(),
      });

    } catch (e) {
      debugPrint('Error handling conversation restored: $e');
    }
  }

  /// Handle user online status
  void _handleUserOnline(dynamic data) {
    _presenceController.add({
      'type': 'online',
      'userId': data['userId'],
      'timestamp': DateTime.parse(data['timestamp']),
    });
  }

  /// Handle user offline status
  void _handleUserOffline(dynamic data) {
    _presenceController.add({
      'type': 'offline',
      'userId': data['userId'],
      'lastSeen': DateTime.parse(data['lastSeen']),
    });
  }

  /// Handle typing start
  void _handleTypingStart(dynamic data) {
    _typingController.add({
      'type': 'start',
      'conversationId': data['conversationId'],
      'userId': data['userId'],
      'timestamp': DateTime.parse(data['timestamp']),
    });
  }

  /// Handle typing stop
  void _handleTypingStop(dynamic data) {
    _typingController.add({
      'type': 'stop',
      'conversationId': data['conversationId'],
      'userId': data['userId'],
      'timestamp': DateTime.parse(data['timestamp']),
    });
  }

  /// Handle sync messages response
  void _handleSyncMessages(dynamic data) async {
    try {
      final messages = (data['messages'] as List)
          .map((json) => Message.fromJson(json))
          .toList();
      
      // Save all messages to local storage
      for (final message in messages) {
        await _chatStorage.saveMessage(message);
        _messageController.add(message);
      }
      
      // Update last sync timestamp
      await _chatStorage.setLastSyncTimestamp(DateTime.now());
      
      debugPrint('Synced ${messages.length} messages from server');
    } catch (e) {
      debugPrint('Error handling sync messages: $e');
    }
  }

  /// Handle sync conversations response
  void _handleSyncConversations(dynamic data) async {
    try {
      final conversations = (data['conversations'] as List)
          .map((json) => Conversation.fromJson(json))
          .toList();
      
      // Save all conversations to local storage
      for (final conversation in conversations) {
        await _chatStorage.saveConversation(conversation);
        _conversationController.add(conversation);
      }
      
      debugPrint('Synced ${conversations.length} conversations from server');
    } catch (e) {
      debugPrint('Error handling sync conversations: $e');
    }
  }

  /// Update conversation with last message
  Future<void> _updateConversationLastMessage(Message message) async {
    try {
      final conversation = await _chatStorage.getConversationById(message.conversationId);
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: message,
          lastMessageTime: message.timestamp,
          unreadCount: conversation.unreadCount + 1,
        );
        await _chatStorage.saveConversation(updatedConversation);
        _conversationController.add(updatedConversation);
      }
    } catch (e) {
      debugPrint('Error updating conversation last message: $e');
    }
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (isConnected) {
        _socket?.emit('ping', {'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_isManualDisconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _updateStatus(SocketStatus.reconnecting);
    
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  /// Update socket status and notify listeners
  void _updateStatus(SocketStatus status) {
    if (_status != status) {
      _status = status;
      _statusController.add(status);
      debugPrint('Socket status changed to: $status');
    }
  }

  /// Get stored authentication token
  Future<String?> _getStoredToken() async {
    return await _chatStorage.getAuthToken();
  }

  /// Get current user ID
  Future<String> _getCurrentUserId() async {
    return await _chatStorage.getCurrentUserId();
  }

  /// Disconnect from socket
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    
    _updateStatus(SocketStatus.disconnected);
  }

  /// Get messages stream for a specific conversation
  Stream<List<Message>> getMessagesStream(String conversationId) async* {
    // Get initial messages from storage
    final initialMessages = await _chatStorage.getMessages(conversationId);
    yield initialMessages;
    
    // Listen to new messages and updates
    await for (final message in _messageController.stream) {
      if (message.conversationId == conversationId) {
        final updatedMessages = await _chatStorage.getMessages(conversationId);
        yield updatedMessages;
      }
    }
  }

  /// Get conversations stream
  Stream<List<Conversation>> getConversationsStream() async* {
    // Get initial conversations from storage
    final initialConversations = await _chatStorage.getConversations();
    yield initialConversations;
    
    // Listen to conversation updates
    await for (final conversation in _conversationController.stream) {
      final updatedConversations = await _chatStorage.getConversations();
      yield updatedConversations;
    }
  }

  /// Delete message via socket
  void deleteMessage(String messageId) {
    if (isConnected) {
      _socket?.emit('delete_message', {
        'messageId': messageId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Send follow notification
  void sendFollowNotification(String followedUserId) {
    if (isConnected) {
      _socket?.emit('follow_notification', {
        'followedUserId': followedUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
    _messageUpdateController.close();
    _conversationController.close();
    _conversationDeleteController.close();
    _typingController.close();
    _presenceController.close();
  }
}