import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/models/response_model.dart' as response_models;
import 'package:vidmeet/services/api_service.dart';
import 'package:vidmeet/services/notification_service.dart';
import 'package:vidmeet/utils/auth_utils.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Use lazy getter to avoid circular dependency
  ApiService get _apiService => ApiService();
  final StreamController<ApiUser?> _authStateController = StreamController<ApiUser?>.broadcast();

  bool _isGoogleLogin = false;
  bool get isGoogleLogin => _isGoogleLogin;

  /// Always provide the latest value immediately to new listeners (BehaviorSubject-like)
  Stream<ApiUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }
  
  ApiUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;

  // Initialize service (lightweight)
  Future<void> initialize() async {
    try {
      await restoreSession();
      await _loadCurrentUser();
      _authStateController.add(_currentUser);
      // Emit initial auth state to unblock UI
      if (!_authStateController.isClosed) {
        _authStateController.add(_currentUser);
      }
      
      print('✅ AuthService initialized');
    } catch (e) {
      print('❌ AuthService init error: $e');
      
      // Still emit null to unblock UI
      if (!_authStateController.isClosed) {
        _authStateController.add(null);
      }
    }
  }

  // inside AuthService
  Future<void> saveSession(ApiUser user) async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refresh_token', _refreshToken!);
    }
    await prefs.setString('user', jsonEncode(user.toJson())); // store user JSON
    await prefs.setBool('is_google_login', _isGoogleLogin);
  }

  Future<ApiUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final refresh = prefs.getString('refresh_token');
    final userJson = prefs.getString('user');
    final googleFlag = prefs.getBool('is_google_login') ?? false;

    _isGoogleLogin = googleFlag;

    if (token != null && userJson != null) {
      try {
        _accessToken = token;
        _refreshToken = refresh ?? token;

        final user = ApiUser.fromJson(jsonDecode(userJson));
        _currentUser = user;

        if (!_authStateController.isClosed) {
          _authStateController.add(_currentUser);
        }
        return user;
      } catch (e) {
        _currentUser = null;
        if (!_authStateController.isClosed) {
          _authStateController.add(null);
        }
      }
    } else {
      _currentUser = null;
      if (!_authStateController.isClosed) {
        _authStateController.add(null);
      }
    }
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    await prefs.remove('is_google_login');
  }

  // Get current user
  ApiUser? get currentUser => _currentUser;

  // Auth state stream

  // Sign up with email and password
  Future<ApiUser?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    try {
      final authResponse = await _apiService.register(
        email: email,
        password: password,
        displayName: displayName,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );

      if (authResponse != null) {
        _accessToken = authResponse.accessToken;
        _refreshToken = authResponse.refreshToken;
        
        // Extract user data from response
        _currentUser = ApiUser.fromJson(authResponse.user);
        _authStateController.add(_currentUser);
        
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with email and password
  Future<ApiUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await _apiService.login(
        email: email,
        password: password,
      );

      if (authResponse != null) {
        _accessToken = authResponse.accessToken;
        _refreshToken = authResponse.refreshToken;
        
        // Extract user data from response
        _currentUser = ApiUser.fromJson(authResponse.user);
        _authStateController.add(_currentUser);
        
        return _currentUser;
      }
      
      return null;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (_isGoogleLogin) {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        _isGoogleLogin = false;
      }

      await NotificationService().deleteToken();
      NotificationService().reset();
      clearSession();
      _currentUser = null;
      _accessToken = null;
      _refreshToken = null;
      _authStateController.add(null);
    } catch (e) {
      throw 'Sign out failed: ${e.toString()}';
    }
  }

  Future<void> deleteAccount() async {
    try {
      if (_isGoogleLogin) {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.disconnect();
        await googleSignIn.signOut();
        _isGoogleLogin = false;
      }

      await NotificationService().deleteToken();
      NotificationService().reset();
      await _apiService.deleteAccount();
      await clearSession();

      _currentUser = null;
      _accessToken = null;
      _refreshToken = null;

      _authStateController.add(null);
      print("✅ Account deleted successfully");
    } catch (e) {
      throw 'Delete account failed: ${e.toString()}';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      // TODO: Implement password reset API call
      throw 'Password reset not implemented yet';
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user profile
  Future<ApiUser?> getUserProfile(String userId) async {
    try {
      return await _apiService.getUserById(userId);
    } catch (e) {
      throw 'Failed to get user profile: ${e.toString()}';
    }
  }

  // Update user profile
  Future<void> updateUserProfile(ApiUser user) async {
    try {
      final updatedUser = await _apiService.updateUserProfile(
        displayName: user.displayName,
        bio: user.bio,
        gender: user.gender,
        dateOfBirth: user.dateOfBirth,
      );
      
      if (updatedUser != null) {
        _currentUser = updatedUser;
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      throw 'Failed to update user profile: ${e.toString()}';
    }
  }

  // Sign in with Google (simplified for demo)
  Future<ApiUser?> signInWithGoogleToken({
    required String idToken,
  }) async {
    try {
      final authResponse = await _apiService.googleLogin(
        token: idToken,
      );

      if (authResponse != null) {
        _accessToken = authResponse.token;
        _refreshToken = authResponse.token;

        _currentUser = ApiUser.fromJson(authResponse.user);
        _authStateController.add(_currentUser);

        _isGoogleLogin = true;
        await saveSession(_currentUser!);

        return _currentUser;
      }

      return null;
    } catch (e) {
      throw 'Google sign in failed: ${e.toString()}';
    }
  }

  // Sign in with Apple (simplified for demo)
  Future<ApiUser?> signInWithAppleToken({
    required String token,
  }) async {
    try {
      final authResponse = await _apiService.appleLogin(
        token: token,
      );

      if (authResponse != null) {
        _accessToken = authResponse.token;
        _refreshToken = authResponse.token;

        _currentUser = ApiUser.fromJson(authResponse.user);
        if (!_authStateController.isClosed) {
          _authStateController.add(_currentUser);
        }

        await saveSession(_currentUser!);

        return _currentUser;
      }

      return null;
    } catch (e) {
      throw 'Apple sign in failed: ${e.toString()}';
    }
  }

  // Sign in as guest
  Future<ApiUser?> signInAsGuest() async {
    try {
      // Create a guest user
      final guestUser = await _createGuestUser();
      
      _currentUser = guestUser;
      await saveSession(guestUser);
      if (!_authStateController.isClosed) {
        _authStateController.add(_currentUser);
      }
      
      return _currentUser;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Check if Apple Sign In is available (simplified for demo)
  Future<bool> isAppleSignInAvailable() async {
    return true; // Always available for demo
  }
  
  // Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;
  
  // Refresh current user data
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      await _loadCurrentUser();
    }
  }
  
  // Private method to load current user
  Future<void> _loadCurrentUser() async {
    try {
      // For now, just check if we have stored auth data
      // TODO: Implement token storage/retrieval when backend is ready
      if (_accessToken != null) {
        // Would call API to get current user data
        // final user = await _apiService.getCurrentUser();
        // For now, maintain existing user if available
        if (_currentUser != null) {
          _authStateController.add(_currentUser);
        }
      }
      print('✅ Current user loaded');
    } catch (e) {
      print('Error loading current user: $e');
      // If loading fails, user might need to re-authenticate
      // _currentUser = null;
      // _authStateController.add(null);
    }
  }

  Future<ApiUser> _createGuestUser() async {
    final deviceId = await AuthUtils().getDeviceId();
    // final deviceId = 'T2SNS33.73-22-3-15';

    print('Creating guest user with device ID: $deviceId');

    final authResponse = await _apiService.guestLogin(deviceId: deviceId);

    if (authResponse != null) {
      _accessToken = authResponse.token;
      _refreshToken = authResponse.token;

      final user = ApiUser.fromJson(authResponse.user);
      return user;
    }

    throw 'Guest login failed';
  }

  // Handle authentication exceptions
  String _handleAuthException(dynamic error) {
    if (error is response_models.ApiException) {
      switch (error.statusCode) {
        case 401:
          return 'Invalid credentials';
        case 403:
          return 'Account disabled';
        case 429:
          return 'Too many requests. Please try again later';
        default:
          return error.message;
      }
    } else if (error is response_models.ValidationException) {
      return error.message;
    } else if (error is response_models.NetworkException) {
      return 'Network error. Please check your connection';
    } else {
      return error.toString();
    }
  }
  
  // // Dispose resources
  // void dispose() {
  //   _authStateController.close();
  // }


}