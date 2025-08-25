import 'dart:convert';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/services/socket_manager.dart';
import 'package:vidstream/storage/chat_storage.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';
import 'package:vidstream/utils/connectivity_service.dart';
import 'package:vidstream/services/http_client.dart';

class ChatService {

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
}