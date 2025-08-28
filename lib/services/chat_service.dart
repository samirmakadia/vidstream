import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService = ApiService();
  ApiRepository get _apiRepository => ApiRepository.instance;

  // Get user's conversations
  Stream<List<Conversation>> getUserConversations() async* {
    try {
      // First yield cached conversations
      final cachedConversations = await ConversationDatabase.instance.getAllConversations( AuthService().currentUser?.id ?? '');
      if (cachedConversations.isNotEmpty) {
        yield cachedConversations;
      }

      // Then get from API
      final apiResponse = await _apiRepository.api.getChatConversations();
      final apiConversations = apiResponse?.data ?? [];
      //await _chatStorage.cacheConversations(apiConversations);
      await ConversationDatabase.instance.replaceAllConversations(apiConversations);
      yield apiConversations;

    } catch (e) {
      print('Error getting conversations: $e');
      final cachedConversations = await ConversationDatabase.instance.getAllConversations( AuthService().currentUser?.id ?? '');
      // final cachedConversations = await _chatStorage.getConversations();
      yield cachedConversations;
    }
  }

  Future<bool> fetchAndCacheConversations() async {
    try {
      final apiResponse = await _apiRepository.api.getChatConversations();
      final apiConversations = apiResponse?.data ?? [];
      await ConversationDatabase.instance.replaceAllConversations(apiConversations);
      return true;
    } catch (e) {
      print('Error fetching conversations: $e');
      return false;
    }
  }

  Future<ApiUser?> getUserById(String userId) async {
    try {
      return await _apiRepository.api.getUserById(userId);
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<List<Message>?> getSyncChatMessages1({required DateTime date}) async {
    try {
      final paginatedResponse = await _apiRepository.api.getSyncChatMessages(date: date);
      return paginatedResponse?.data;
    } catch (e) {
      print('❌ Error syncing chat messages: $e');
      return null;
    }
  }

  Future<void> deleteChatConversation(String id) async {
    try {
      await _apiService.deleteChatConversation(id);
    } catch (e) {
      throw 'Failed to delete comment: ${e.toString()}';
    }
  }

  Future<void> deleteChatMessage(String messageId) async {
    try {
      await _apiService.deleteMessage(messageId);
    } catch (e) {
      throw 'Failed to delete comment: ${e.toString()}';
    }
  }

}