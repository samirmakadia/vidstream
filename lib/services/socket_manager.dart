import 'dart:async';
import 'dart:convert';
import 'package:event_bus/event_bus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vidstream/storage/conversation_storage_drift.dart';
import '../manager/session_manager.dart';
import '../models/api_models.dart';
import '../storage/message_storage_drift.dart';
import 'package:flutter/foundation.dart';

import '../utils/utils.dart';
import 'auth_service.dart';
import 'chat_service.dart';

final EventBus eventBus = EventBus();

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;
  SocketManager._internal();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  String? _currentUserId;

  IO.Socket? _socket;

  Future<void> connect({required String token}) async {
    disconnect();

    _currentUserId = _authService.currentUser?.id ?? "";

    _socket = IO.io(
      'https://creatives-macbook-air-2.taild45175.ts.net',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.on('connect', (_) async {
      print("✅ Socket connected successfully with token: $token");
      await _syncMessagesSinceLastSync();
    });

    _socket?.on('connect_error', (err) {
      print("❌ Socket connection error: $err");
    });

    _socket?.on('message', _handleMessage);

    _socket?.on('userJoinedMeet', _handleUserJoinedMeet);
    _socket?.on('userLeftMeet', _handleUserLeftMeet);

  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _handleMessage(dynamic data) async {
    print("🔔 Incoming message data: $data");

    // Cast data safely
    final Map<String, dynamic> jsonData = (data as Map).cast<String, dynamic>();

    final message = Message.fromJson(jsonData);

    final currentUserId = _currentUserId ?? "";
    if (currentUserId.isEmpty) return;

    final receiverId = _getReceiverId(message.conversationId, currentUserId);

    // Update conversation lastMessageId
    await ConversationDatabase.instance.updateLastMessageIdByConversationId(message.conversationId, message.messageId);

    // Only send delivered if the message is still in 'sent' status
    if (message.status == MessageStatus.sent) {
      final deliveredPayload = {
        ...message.toSocketJson(),
        "messageId": message.messageId,
        "status": "delivered",
        "receiverId": receiverId,
      };
      print("📤 Sending Delivered Payload:\n$deliveredPayload");
      _socket?.emit("message", deliveredPayload);

      // Update locally
      final messageDeliveredMap = {
        ...jsonData,
        "messageId": message.messageId,
        "status": "delivered",
        "receiverId": receiverId,
      };

      final messageDelivered = Message.fromJson(messageDeliveredMap);
      await MessageDatabase.instance.addOrUpdateMessage(messageDelivered);
      Utils.saveLastSyncDate();
      debugPrint("📩 Delivered receipt sent for message ${message.messageId}");
    } else {
      // just update local db with whatever status came from server
      await MessageDatabase.instance.addOrUpdateMessage(message);
      debugPrint("✅ Message ${message.messageId} updated with status ${message.status}");
    }
  }

  String _getReceiverId(String conversationId, String currentUserId) {
    final parts = conversationId.split('-');
    if (parts.length != 2) return "";
    return parts.first == currentUserId ? parts.last : parts.first;
  }

  Future<void> sendSeenEvent(Message message, String? receiverId) async {
    try {
      final setSeenPayload = {
        ...message.toSocketJson(),
        "status": "read",
        "receiverId": receiverId,
      };
      print("📤 Sending Seen Payload:\n$setSeenPayload");
      _socket?.emit('message', setSeenPayload);
      print("👁️ Message ${message.messageId} marked as seen");
      Utils.saveLastSyncDate();
    } catch (e) {
      print("Error in sendSeenEvent: $e");
    }
  }

  void sendMessage(Message message) async {
    try {
      String jsonString = jsonEncode(message.toSocketJson());
      print(jsonString);

      _socket?.emit('message', message.toSocketJson());

      await MessageDatabase.instance.addOrUpdateMessage(message);

      debugPrint("✅ Message sent and saved: ${message.messageId}");
    } catch (e, stack) {
      debugPrint("❌ Error sending message: $e\n$stack");
    }
  }

  void _handleUserJoinedMeet(dynamic data) async {
    debugPrint("👥 userJoinedMeet event: $data");
    try {
      final userId = data['userId'];
      if (userId != null) {
        eventBus.fire(MeetEvent(userId: userId, type: MeetEventType.joined));
      }
    } catch (e) {
      debugPrint("❌ Error handling userJoinedMeet: $e");
    }
  }

  void _handleUserLeftMeet(dynamic data) async {
    debugPrint("👤 userLeftMeet event: $data");
    try {
      final userId = data['userId'];
      if (userId != null) {
        eventBus.fire(MeetEvent(userId: userId, type: MeetEventType.left));
      }
    } catch (e) {
      debugPrint("❌ Error handling userLeftMeet: $e");
    }
  }

  Future<void> _syncMessagesSinceLastSync() async {
    try {

      final DateTime sinceDate = await Utils.getLastSyncDate() ??
          DateTime.now().subtract(const Duration(days: 1));

      final messages = await _chatService.getSyncChatMessages(date: sinceDate);

      if (messages != null && messages.isNotEmpty) {
        for (var message in messages) {
          final currentUserId = _currentUserId ?? "";
          final receiverId = _getReceiverId(message.conversationId, currentUserId);

          await MessageDatabase.instance.addOrUpdateMessage(message);
          // if (message.status == MessageStatus.sent) {
          //   await _sendDeliveredReceipt(message, message.toJson(), receiverId);
          // }
        }
      }

      Utils.saveLastSyncDate();
      print("🟢 Messages synced successfully since $sinceDate");

    } catch (e, stack) {
      debugPrint("❌ Error syncing messages: $e\n$stack");
    }
  }



}


enum MeetEventType { joined, left }

class MeetEvent {
  final String userId;
  final MeetEventType type;

  MeetEvent({
    required this.userId,
    required this.type,
  });
}