import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;

  SessionManager._internal();

  String? _sessionId;

  String get sessionId {
    _sessionId ??= const Uuid().v4();
    return _sessionId!;
  }

  void resetSession() {
    _sessionId = const Uuid().v4();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}
