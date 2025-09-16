import 'dart:async';
import 'dart:convert';
import 'package:event_bus/event_bus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vidmeet/storage/conversation_storage_drift.dart';
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

    _socket?.on('message_deleted', _handleMessageDeleted);

    _socket?.on('userOnline', _handleUserOnline);
    _socket?.on('userOffline', _handleUserOffline);

    _socket?.on('typing', _handleTypingEvent);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _handleMessage(dynamic data) async {
    print("🔔 Incoming message data: $data");

    final Map<String, dynamic> jsonData = (data as Map).cast<String, dynamic>();

    final message = MessageModel.fromJson(jsonData);

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
    final parts = conversationId.split('-');
    if (parts.length != 2) return "";
    return parts[0] == senderId ? parts[1] : parts[0];
  }

  Future<void> sendSeenEvent(MessageModel message, String currentUserId) async {
    try {
      final receiverId = _getReceiverId(conversationId: message.conversationId, currentUserId: currentUserId, senderId: message.senderId,);

      final setSeenPayload = {
        ...message.toSocketJson(),
        "status": "read",
        "receiverId": receiverId,
      };
      print("📤 Sending Seen Payload:\n$setSeenPayload");
      _socket?.emit('message', setSeenPayload);
      await MessageDatabase.instance.updateMessageStatus(message.messageId, MessageStatus.read.name);
      print("👁️ Message ${message.messageId} marked as seen");
      Utils.saveLastSyncDate();
    } catch (e) {
      print("Error in sendSeenEvent: $e");
    }
  }

  void sendMessage(MessageModel message) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      String jsonString = jsonEncode(message.toSocketJson());
      print(jsonString);

      _socket?.emit('message', message.toSocketJson());

      final localMessage = message.copyWith(
        status: MessageStatus.pending,
        createdAt: nowIso,
        updatedAt: nowIso,
      );
      await MessageDatabase.instance.addOrUpdateMessage(localMessage);

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

  void _handleUserOnline(dynamic data) {
    try {
      final userId = data['userId'];
      if (userId != null) {
        //eventBus.fire(MeetEvent(userId: userId, type: MeetEventType.online));
        ConversationDatabase.instance.updateUserOnlineStatus(userId, true);
        print("🟢 User $userId is online");
      }
    } catch (e) {
      debugPrint("❌ Error handling userOnline: $e");
    }
  }

  void _handleUserOffline(dynamic data) {
    try {
      final userId = data['userId'];
      if (userId != null) {
        // eventBus.fire(MeetEvent(userId: userId, type: MeetEventType.offline));
        ConversationDatabase.instance.updateUserOnlineStatus(userId, false);
        print("🔴 User $userId is offline");
      }
    } catch (e) {
      debugPrint("❌ Error handling userOffline: $e");
    }
  }

  void _handleTypingEvent(dynamic data) {
    try {
      print("📤 Received typing event: $data");
      final jsonData = (data as Map).cast<String, dynamic>();

      final conversationId = jsonData['conversationId'] as String?;
      final receiverId = jsonData['receiverId'] as String?;
      _currentUserId = _authService.currentUser?.id ?? "";

      print("📤 _currentUserId: $_currentUserId, receiverId: $receiverId");

      if (conversationId != null && receiverId != null && receiverId == _currentUserId) {

        if (receiverId.isNotEmpty) {
          eventBus.fire(TypingEvent(
            receiverId: receiverId,
            conversationId: conversationId,
          ));
        }
      }
    } catch (e) {
      debugPrint("❌ Error handling typing event: $e");
    }
  }

  void sendTypingEvent({
    required String conversationId,
  }) {
    _currentUserId = _authService.currentUser?.id ?? "";
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    final receiverId = _getReceiverId(
      conversationId: conversationId,
      currentUserId: _currentUserId!,
      senderId: _currentUserId!,
    );

    final payload = {
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'conversationId': conversationId,
    };

    print("✍️ Sending typing event: $payload");
    _socket?.emit('typing', payload);
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

          await ConversationDatabase.instance.updateLastMessageIdByConversationId(message.conversationId, message.messageId);

          if (message.status == MessageStatus.sent && message.senderId != _currentUserId) {
            await _sendDeliveredReceipt(message, message.toSocketJson(),receiverId,);
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
      MessageModel message,
      Map<String, dynamic> messageJson,
      String receiverId,
      ) async {
    try {

      final deliveredPayload = {
        ...messageJson,
        "id": message.id,
        "messageId": message.messageId,
        "status": "delivered",
        "receiverId": receiverId,
      };

      print("📤 Sending Delivered Receipt:\n$deliveredPayload");

      _socket?.emit("message", deliveredPayload);

      final updatedMessage = MessageModel.fromJson({
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

  void _handleMessageDeleted(dynamic data) async {
    try {
      print("🗑️ Message deleted event received: $data");

      // Extract messageId from payload
      final Map<String, dynamic> jsonData = (data as Map).cast<String, dynamic>();
      final String? messageId = jsonData['messageId'];

      if (messageId != null && messageId.isNotEmpty) {
        // Delete from local database
        await MessageDatabase.instance.deleteMessageById(messageId);

        eventBus.fire('message_deleted');

        print("✅ Message $messageId deleted locally");
      } else {
        print("⚠️ messageId not found in event payload");
      }
    } catch (e, stack) {
      debugPrint("❌ Error handling message_deleted: $e\n$stack");
    }
  }

}


enum MeetEventType { joined, left, online, offline }

class MeetEvent {
  final String userId;
  final MeetEventType type;

  MeetEvent({
    required this.userId,
    required this.type,
  });
}


class TypingEvent {
  final String receiverId;
  final String conversationId;

  TypingEvent({
    required this.receiverId,
    required this.conversationId,
  });
}