import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/models/api_models.dart';

class AuthUtils {
  /// Check if user is properly authenticated
  static bool isUserAuthenticated() {
    final user = ApiRepository.instance.auth.currentUser;
    return user != null;
  }

  /// Get current user ID or null if not authenticated
  static String? getCurrentUserId() {
    return ApiRepository.instance.auth.currentUser?.id;
  }

  /// Check if user is authenticated and throw helpful exception if not
  static void requireAuthentication() {
    if (!isUserAuthenticated()) {
      throw Exception('Authentication required. Please sign in to continue.');
    }
  }

  /// Get user display name for UI
  static String getUserDisplayName() {
    final user = ApiRepository.instance.auth.currentUser;
    if (user != null) {
      return user.displayName.isNotEmpty ? user.displayName : 
             user.email.split('@').first;
    }
    return 'Guest';
  }

  /// Check if user is a guest user
  static bool isGuestUser() {
    final user = ApiRepository.instance.auth.currentUser;
    return user?.isGuest ?? false;
  }

  /// Get current user or null
  static ApiUser? getCurrentUser() {
    return ApiRepository.instance.auth.currentUser;
  }

  /// Get authentication status for debugging
  static Map<String, dynamic> getAuthStatus() {
    final user = ApiRepository.instance.auth.currentUser;
    if (user == null) {
      return {
        'authenticated': false,
        'id': null,
        'email': null,
        'displayName': null,
        'isGuest': null,
      };
    }

    return {
      'authenticated': true,
      'id': user.id,
      'email': user.email,
      'displayName': user.displayName,
      'isGuest': user.isGuest,
    };
  }

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? '';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? '';
    } else {
      return '';
    }
  }
}