import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/utils.dart';

class FirebaseManager {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    NotificationSettings notificationSettings =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      criticalAlert: true,
      carPlay: false,
      provisional: false,
    );

    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.authorized) {
      final String? apnsToken = await _firebaseMessaging.getAPNSToken();
      print('APNs Token: $apnsToken');

      await _getFCMToken();
      var initializationSettingsAndroid =
      const AndroidInitializationSettings('@mipmap/ic_launcher');
      var initializationSettingsIOS = const DarwinInitializationSettings();
      var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
          if (notificationResponse.payload != null) {
            print(
                "NOTIFICATION PAYLOAD ============ ${notificationResponse.payload}");
            _handleNotificationClickPayload(notificationResponse.payload!);
          }
        },
      );

      await _getFCMToken();

      _setForegroundMessageHandler();
      _setBackgroundMessageHandler();

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          if (message.data.isNotEmpty) {
            print("Data payload: ${message.data}");
          } else {
            print("No data payload received.");
          }
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data.isNotEmpty) {
          print("Data payload: ${message.data}");
          _handleNotificationClickPayload(jsonEncode(message.data));
        } else {
          print("No data payload received.");
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _getFCMToken() async {
    final String? fcmToken = await _firebaseMessaging.getToken();
    String? deviceId = await Utils.getDeviceId();

     print(fcmToken);
  }

  void _setForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Received a foreground message: ${message.notification?.title}');
      await _showNotification(message);
    });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    print('Notification data: ${message.data}');

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
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

    // Ensure the payload contains the message data as JSON
    final payload = jsonEncode(message.data);
    print('payload ${payload}');
    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      platformDetails,
      payload: payload,
    );
  }

  Future<void> _setBackgroundMessageHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');

    await Firebase.initializeApp();

    FirebaseManager._handleNotificationClickPayload(jsonEncode(message.data));
  }

  static Future<void> _handleNotificationClickPayload(String payload) async {
    print(payload);
    if (payload.isEmpty) return;
    final data = jsonDecode(payload);

    if (data.containsKey('msg')) {
      final msgData = data['msg'];

    } else if (data.containsKey('data')) {
      final msgData = data['data'];
      if (msgData != null && msgData.isNotEmpty) {
        final jsonObject = jsonDecode(msgData);

      }
    }
  }
}
