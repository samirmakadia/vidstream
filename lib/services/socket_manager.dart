import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/api_models.dart';
import '../storage/message_storage_drift.dart';

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  factory SocketManager() => _instance;
  SocketManager._internal();

  IO.Socket? _socket;

  /// Connect to socket server with bearer token
  Future<void> connect({required String token}) async {
    disconnect(); // Ensure previous socket is closed

    _socket = IO.io(
      'https://collie-humorous-goose.ngrok-free.app',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .setAuth({'token': token})
        .build()
    );

    _socket?.on('message', _handleMessage);
  }

  /// Disconnect from socket server
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Handle incoming message event and store/update in local storage
  void _handleMessage(dynamic data) async {
    final message = Message.fromJson(data);
    // Store or update message in local storage
    MessageDatabase.instance.addOrUpdateMessage(message);
  }

}