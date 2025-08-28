import 'dart:async';
import 'dart:convert';
import 'package:event_bus/event_bus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vidstream/storage/conversation_storage_drift.dart';
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

    final Map<String, dynamic> jsonData = (data as Map).cast<String, dynamic>();

    final message = Message.fromJson(jsonData);

    final currentUserId = _currentUserId ?? "";
    final receiverId = _getReceiverId(
      conversationId: message.conversationId,
      currentUserId: currentUserId,
      senderId: message.senderId,
    );

    await ConversationDatabase.instance.updateLastMessageIdByConversationId(message.conversationId, message.messageId);
    print("🔎 Checking IDs: receiverId=$receiverId, currentUserId=$currentUserId, conversationId=${message.conversationId}, senderId=${message.senderId}");

    if (message.status == MessageStatus.sent && message.senderId != _currentUserId) {
      await _sendDeliveredReceipt(message, message.toSocketJson(), receiverId);
    }
    else {
      await MessageDatabase.instance.addOrUpdateMessage(message);
      debugPrint("✅ Message ${message.messageId} updated with status ${message.status}");
    }
  }

  String _getReceiverId({
    required String conversationId,
    required String currentUserId,
    required String senderId,
  }) {
    // If I am the sender → receiver is the other participant
    if (senderId == currentUserId) {
      final parts = conversationId.split('-');
      if (parts.length != 2) return "";
      return parts[0] == currentUserId ? parts[1] : parts[0];
    }

    // If I am NOT the sender → I am the receiver
    return currentUserId;
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

      debugPrint("✅ Message sent and saved: ${message.content.text}, status: ${message.status}");
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
      final DateTime sinceDate = (await Utils.getLastSyncDate())?.toUtc() ?? DateTime.now().subtract(const Duration(days: 1)).toUtc();

      final messages = await _chatService.getSyncChatMessages1(date: sinceDate);

      if (messages != null && messages.isNotEmpty) {
        for (var message in messages) {
          final currentUserId = _currentUserId ?? "";
          final receiverId = _getReceiverId(
            conversationId: message.conversationId,
            currentUserId: currentUserId,
            senderId: message.senderId,
          );

          if (message.status == MessageStatus.sent && message.senderId != _currentUserId) {
            await _sendDeliveredReceipt(message, message.toJson(),receiverId,);
          }
          else {
            await MessageDatabase.instance.addOrUpdateMessage(message);
          }
        }
      }

      await Utils.saveLastSyncDate();

      print("🟢 Messages synced successfully since $sinceDate");
    } catch (e, stack) {
      debugPrint("❌ Error syncing messages: $e\n$stack");
    }
  }


  Future<void> _sendDeliveredReceipt(
      Message message,
      Map<String, dynamic> messageJson,
      String receiverId,
      ) async {
    try {

      final deliveredPayload = {
        ...messageJson,
        "messageId": message.messageId,
        "status": "delivered",
        "receiverId": receiverId,
      };

      print("📤 Sending Delivered Receipt:\n$deliveredPayload");

      _socket?.emit("message", deliveredPayload);

      final updatedMessage = Message.fromJson({
        ...messageJson,
        "messageId": message.messageId,
        "status": "delivered",
        "receiverId": receiverId,
      });

      await MessageDatabase.instance.addOrUpdateMessage(updatedMessage);
      await Utils.saveLastSyncDate();
      debugPrint("📩 Delivered receipt sent for message ${message.messageId}");
    } catch (e, stack) {
      debugPrint("❌ Error sending delivered receipt: $e\n$stack");
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