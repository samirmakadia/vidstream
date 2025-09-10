import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/screens/other_user_profile_screen.dart';
import 'package:vidmeet/utils/utils.dart';

import '../main.dart';
import '../screens/chat_screen.dart';
import 'api_service.dart';

class NotificationService {

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();


  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiRepository _apiRepository = ApiRepository.instance;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeLocalNotifications();

      final fcmToken = await getFcmToken();
      if (fcmToken != null) {
        await updateFcmToken(fcmToken);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen(updateFcmToken);

      _setForegroundMessageHandler();
      _setBackgroundMessageHandler();

      await listenToNotifications();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ NotificationService initialization failed: $e');
    }
  }

  void _setForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Received a foreground message: ${message.notification?.title}');
      await _showNotification(message);
    });
  }

  Future<void> _setBackgroundMessageHandler() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    final payload = jsonEncode({
      ...message.data,
      "title": message.notification?.title ?? '',
      "body": message.notification?.body ?? '',
    });
    print('Handling notification click with payload: $message');
    await NotificationService.handleNotificationClickPayload(payload);
  }

  static Future<void> handleNotificationClickPayload(String payload) async {
    print('Handling notification click with payload: $payload');
    if (payload.isEmpty) return;

    try {
      final data = jsonDecode(payload);

      final String? type = data['type'];

      if (type == null) return;

      if (type == 'user' && data['user'] != null) {
        var rawUser = data['user'];

        if (rawUser is String) {
          final userJson = Utils.parseNotificationMessage(rawUser);
          if (userJson.isNotEmpty) {
            final userModel = ApiUser.fromJson(userJson);

            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => OtherUserProfileScreen(
                  userId: userModel.id,
                  displayName: userModel.displayName,
                ),
              ),
            );
          }
        }
      } else if (type == 'message' && data['message'] != null) {
        var rawMessage = data['message'];

        if (rawMessage is String) {
          final messageJson = Utils.parseNotificationMessage(rawMessage);
          if (messageJson.isNotEmpty) {
            final messageModel = MessageModel.fromJson(messageJson);

            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: messageModel.conversationId,
                  otherUserId: messageModel.senderId,
                  name: data['title'] ?? 'Chat',
                ),
              ),
            );
          }
        }
      }
    } catch (e,s) {
      debugPrint('Error parsing notification payload: $s');
      debugPrint("❌ Error parsing notification payload: $e");
    }
  }



  Future<void> _showNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'Default',
      'Default channel',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    var iosDetails = const DarwinNotificationDetails();
    var platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      ...message.data,
      "title": message.notification?.title ?? '',
      "body": message.notification?.body ?? '',
    });

    print('payload $payload');

    await _localNotifications.show(
      message.hashCode, // use unique id
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      platformDetails,
      payload: payload,
    );
  }


  Future<void> listenToNotifications() async {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      print('App opened from terminated state via notification$message');
      if (message != null) {
        final payload = jsonEncode({
          ...message.data,
          "title": message.notification?.title ?? '',
          "body": message.notification?.body ?? '',
        });
        NotificationService.handleNotificationClickPayload(payload);
      } 
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from terminated state via notification$message');
      final payload = jsonEncode({
        ...message.data,
        "title": message.notification?.title ?? '',
        "body": message.notification?.body ?? '',
      });
      NotificationService.handleNotificationClickPayload(payload);
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // --- iOS Permission ---
    if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (granted != true) {
        debugPrint("❌ iOS notification permission not granted");
      } else {
        debugPrint("✅ iOS notification permission granted");

        // --- Add this to get APNs token ---
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        debugPrint("✅ APNs token: $apnsToken");
      }
    }

    // --- Android 13+ Permission ---
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidPlugin?.requestNotificationsPermission();

      if (granted != true) {
        debugPrint("❌ Android notification permission not granted");
      } else {
        debugPrint("✅ Android notification permission granted");
      }
    }
  }



  void _onDidReceiveNotificationResponse(NotificationResponse response) async {
    final String? payload = response.payload;
    print('App opened from terminated state via notification$payload');

    if (payload != null && payload.isNotEmpty) {
      await NotificationService.handleNotificationClickPayload(payload);
    }
  }

  // Send push notification via API
  Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _apiRepository.api.sendNotification(
        userId: toUserId,
        title: title,
        body: body,
        data: data?.cast<String, String>(),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }


  Future<String?> getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint("✅ Obtained FCM token: $token");
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> updateFcmToken(String token) async {
    try {
      final platform = Utils.getDeviceType();
      final deviceInfo = await Utils.getDeviceUniqueId();
      await ApiService().registerFcmToken(
        token: token,
        platform: platform,
        deviceInfo: deviceInfo,
      );

      debugPrint("✅ FCM token registered with backend");
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _apiRepository.api.subscribeToNotificationTopic(topic);
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _apiRepository.api.unsubscribeFromNotificationTopic(topic);
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }


  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

   Future<void> clearNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('Error clearing notification: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      final token = await getFcmToken();
      if (token != null && token.isNotEmpty) {
        await _apiRepository.api.deactivateFcmToken(token: token);
        await FirebaseMessaging.instance.deleteToken();
      } else {
        debugPrint("⚠️ No FCM token found to delete");
      }
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  void reset() {
    _isInitialized = false;
  }

  // Send notification to user (for backwards compatibility)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, String>? data,
  }) async {
    await sendNotification(
      toUserId: userId,
      title: title,
      body: body,
      data: data?.cast<String, dynamic>(),
    );
  }
}