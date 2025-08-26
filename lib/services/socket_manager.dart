import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vidstream/storage/conversation_storage_drift.dart';
import '../models/api_models.dart';
import '../storage/message_storage_drift.dart';
import 'package:flutter/foundation.dart';

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;
  SocketManager._internal();

  IO.Socket? _socket;

  final _userJoinedController = StreamController<String>.broadcast(); // userId
  final _userLeftController = StreamController<String>.broadcast(); // userId

  // 👇 getters
  Stream<String> get onUserJoinedMeet => _userJoinedController.stream;
  Stream<String> get onUserLeftMeet => _userLeftController.stream;

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

    // Handle incoming messages
    _socket?.on('message', _handleMessage);

    _socket?.on('userJoinedMeet', _handleUserJoinedMeet);
    _socket?.on('userLeftMeet', _handleUserLeftMeet);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Handle incoming message event and store/update in local storage
  void _handleMessage(dynamic data) async {
    print("🔔 Incoming message data: $data");
    final message = Message.fromJson(data);
    debugPrint("⬅️ Message received from socket: ${message.id} | ${message.message}");

    // Save or update in local DB
    await MessageDatabase.instance.addOrUpdateMessage(message);
    await ConversationDatabase.instance.updateLastMessageIdByConversationId(message.conversationId, message.id);
  }

  void sendMessage(Message message) async {
    try {
      // Convert message to JSON string
      String jsonString = jsonEncode(message.toSocketJson());
      print(jsonString);

      _socket?.emit('message', message.toSocketJson());

      // Save the message locally in DB
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
        _userJoinedController.add(userId);
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
        _userLeftController.add(userId);
      }
    } catch (e) {
      debugPrint("❌ Error handling userLeftMeet: $e");
    }
  }

}
