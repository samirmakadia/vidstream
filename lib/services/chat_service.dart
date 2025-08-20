import 'dart:convert';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/services/socket_manager.dart';
import 'package:vidstream/storage/chat_storage.dart';
import 'package:vidstream/utils/connectivity_service.dart';
import 'package:vidstream/services/http_client.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService({
    SocketManager? socketManager,
    ChatStorage? chatStorage,
    dynamic connectivityService,
    dynamic httpClient,
  }) => _instance;
  ChatService._internal();

  ApiRepository get _apiRepository => ApiRepository.instance;
  late final SocketManager _socketManager;
  late final ChatStorage _chatStorage;

  Future<void> initialize({
    SocketManager? socketManager,
    ChatStorage? chatStorage,
    dynamic connectivityService,
    dynamic httpClient,
  }) async {
    try {
      _socketManager = socketManager ?? SocketManager();
      _chatStorage = chatStorage ?? ChatStorage();
      
      // Initialize services with error handling
      _socketManager.initialize(
        chatStorage: _chatStorage,
        connectivityService: connectivityService ?? ConnectivityService(),
        httpClient: httpClient ?? HttpClient(),
      ).catchError((e) => print('Socket init error: $e'));
      
      _chatStorage.initialize().catchError((e) => print('Storage init error: $e'));
      
      print('✅ ChatService initialized');
    } catch (e) {
      print('❌ ChatService init error: $e');
      // Don't throw - let app continue
    }
  }

  void dispose() {
    _socketManager.dispose();
  }

  // Get or create a conversation between two users
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      // First try to get existing conversation from API
      final conversationsResponse = await _apiRepository.api.getChatConversations();
      final conversations = conversationsResponse?.data ?? [];
      final existingConversation = conversations.firstWhere(
        (conv) => conv.participants.contains(otherUserId),
        orElse: () => Conversation(
          id: '',
          participants: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingConversation.id.isNotEmpty) {
        return existingConversation.id;
      }

      // Create new conversation  
      final currentUserId = _apiRepository.auth.currentUser?.id ?? '';
      final conversationId = await _apiRepository.api.createOrGetConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      return conversationId;
    } catch (e) {
      throw 'Failed to get or create conversation: $e';
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String messageType,
    required Map<String, dynamic> content,
    String? replyToId,
  }) async {
    final currentUserId = _apiRepository.auth.currentUser?.id;
    if (currentUserId == null) throw 'User not authenticated';

    try {
      // Create temporary message for immediate UI update
      final tempMessage = Message(
        id: '',
        conversationId: conversationId,
        senderId: currentUserId,
        messageType: messageType,
        content: content,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        replyToId: replyToId,
        tempId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Store locally first
      await _chatStorage.addMessage(tempMessage);

      // Send via Socket.IO for real-time delivery
      _socketManager.sendMessage(
        conversationId: conversationId,
        messageType: messageType,
        content: content,
        replyToId: replyToId,
      );

      // Also send to API for persistence
      await _apiRepository.api.sendChatMessage(
        conversationId: conversationId,
        messageType: messageType,
        content: jsonEncode(content),
        mediaUrl: content['media_url'] as String?,
      );
    } catch (e) {
      // Update message status to failed
      throw 'Failed to send message: $e';
    }
  }

  // Get messages for a conversation
  Stream<List<Message>> getMessages(String conversationId, {int limit = 50}) async* {
    try {
      // First yield cached messages
      final cachedMessages = await _chatStorage.getMessages(conversationId);
      if (cachedMessages.isNotEmpty) {
        yield cachedMessages;
      }

      // Then get from API and cache
      final apiResponse = await _apiRepository.api.getChatMessages(conversationId: conversationId);
      final apiMessages = apiResponse?.data ?? [];
      await _chatStorage.cacheMessages(apiMessages);
      yield apiMessages;

      // Listen for real-time updates via Socket.IO
      await for (final realtimeMessages in _socketManager.getMessagesStream(conversationId)) {
        yield realtimeMessages;
      }
    } catch (e) {
      print('Error getting messages: $e');
      // Fallback to cached messages
      final cachedMessages = await _chatStorage.getMessages(conversationId);
      yield cachedMessages;
    }
  }

  // Get user's conversations
  Stream<List<Conversation>> getUserConversations() async* {
    try {
      // First yield cached conversations
      final cachedConversations = await _chatStorage.getConversations();
      if (cachedConversations.isNotEmpty) {
        yield cachedConversations;
      }

      // Then get from API
      final apiResponse = await _apiRepository.api.getChatConversations();
      final apiConversations = apiResponse?.data ?? [];
      await _chatStorage.cacheConversations(apiConversations);
      yield apiConversations;

      // Listen for real-time updates
      await for (final realtimeConversations in _socketManager.getConversationsStream()) {
        yield realtimeConversations;
      }
    } catch (e) {
      print('Error getting conversations: $e');
      final cachedConversations = await _chatStorage.getConversations();
      yield cachedConversations;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, List<String> messageIds) async {
    try {
      await _apiRepository.api.markChatMessagesAsRead(conversationId: conversationId, messageIds: messageIds);
      _socketManager.markMessagesAsRead(conversationId: conversationId, messageIds: messageIds);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _apiRepository.api.deleteMessage(messageId);
      await _chatStorage.deleteMessage(messageId);
      _socketManager.deleteMessage(messageId);
    } catch (e) {
      throw 'Failed to delete message: $e';
    }
  }

  // Get other user info for a conversation
  Future<ApiUser?> getOtherUser(String conversationId, String currentUserId) async {
    try {
      final conversation = await _apiRepository.api.getConversation(conversationId);
      if (conversation == null) return null;
      final otherUserId = conversation.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return null;
      return await _apiRepository.api.getUserProfile(otherUserId);
    } catch (e) {
      print('Error getting other user: $e');
      return null;
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = _apiRepository.auth.currentUser?.id ?? '';
      return await _apiRepository.api.isUserBlocked(checkerId: currentUserId, checkedId: userId);
    } catch (e) {
      print('Error checking if user blocked: $e');
      return false;
    }
  }

  // Get user by ID
  Future<ApiUser?> getUserById(String userId) async {
    try {
      return await _apiRepository.api.getUserById(userId);
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Get all messages for a conversation (for real-time listen)
  Stream<List<Message>> listenToMessages(String conversationId) {
    return _socketManager.getMessagesStream(conversationId);
  }
}