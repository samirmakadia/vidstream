import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidstream/theme.dart';
import 'package:vidstream/screens/auth_screen.dart';
import 'package:vidstream/screens/main_app_screen.dart';
import 'package:vidstream/screens/onboarding_screen.dart';
import 'package:vidstream/services/notification_service.dart';
import 'package:vidstream/services/dialog_manager_service.dart';
import 'package:vidstream/services/service_locator.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services (non-blocking)
  await _initializeServices();

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize services in the background
Future<void> _initializeServices() async {
  try {
    await Firebase.initializeApp();
    await ServiceLocator.initialize();
    await ApiRepository.instance.initialize();
    await DialogManagerService().initialize();
    // await ChatService().initialize();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ All services initialized successfully');
  } catch (e) {
    print('❌ Service initialization error: $e');
    // Don't block app startup - services can retry later
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidStream',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
    );
  }
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService.handleNotificationClickPayload(jsonEncode(message.data));
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await ApiRepository.instance.initialize();
    await _checkOnboardingStatus();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiRepository.instance.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_completed') ?? false;
      _onboardingCompleted = completed;
    } catch (e) {
      print('Error checking onboarding status: $e');
      _onboardingCompleted = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && mounted) {
      // Handle app resume - check for updates and rating
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          DialogManagerService().handleAppResume(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Show onboarding if not completed
    if (!_onboardingCompleted) {
      return const OnboardingScreen();
    }

    // Show auth/main app flow
    return StreamBuilder<ApiUser?>(
      stream: ApiRepository.instance.auth.authStateChanges,
      builder: (context, snapshot) {

        if (snapshot.hasData) {
          return const MainAppScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

