import 'dart:async';
import 'dart:convert';
import 'package:event_bus/event_bus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vidstream/storage/conversation_storage_drift.dart';
import '../models/api_models.dart';
import '../storage/message_storage_drift.dart';
import 'package:flutter/foundation.dart';

final EventBus eventBus = EventBus();

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;
  SocketManager._internal();

  IO.Socket? _socket;

  Future<void> connect({required String token}) async {
    disconnect();

    _socket = IO.io(
      'https://creatives-macbook-air-2.taild45175.ts.net',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket?.on('connect', (_) {
      print("✅ Socket connected successfully with token: $token");
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
    final message = Message.fromJson(data);

    await ConversationDatabase.instance.updateLastMessageIdByConversationId(message.conversationId, message.id);

    final deliveredPayload = {
      ...message.toSocketJson(),
      "status": "delivered",
    };

    _socket?.emit("message", deliveredPayload);

    final Map<String, dynamic> messageDeliveredMap = {
      ...data,
      "status": "delivered",
    };

    final messageDelivered = Message.fromJson(messageDeliveredMap);
    await MessageDatabase.instance.addOrUpdateMessage(messageDelivered);

    debugPrint("📩 Delivered receipt sent for message ${message.id}");
  }

  void sendMessage(Message message) async {
    try {
      String jsonString = jsonEncode(message.toSocketJson());
      print(jsonString);

      _socket?.emit('message', message.toSocketJson());

      await MessageDatabase.instance.addOrUpdateMessage(message);

      debugPrint("✅ Message sent and saved: ${message.id}");
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