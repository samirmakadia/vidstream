import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:applovin_max/applovin_max.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidmeet/theme.dart';
import 'package:vidmeet/screens/auth_screen.dart';
import 'package:vidmeet/screens/main_app_screen.dart';
import 'package:vidmeet/screens/onboarding_screen.dart';
import 'package:vidmeet/services/notification_service.dart';
import 'package:vidmeet/services/dialog_manager_service.dart';
import 'package:vidmeet/services/service_locator.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/models/api_models.dart';
import 'manager/app_open_ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeServices();
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initializeServices() async {
  try {
    AppLovinMAX.setTestDeviceAdvertisingIds(["dd1c479f-a0c8-4d54-985c-7568bc3d6ba1"]);
    AppLovinMAX.setVerboseLogging(true);
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (Platform.isAndroid) {
    //     AppLovinMAX.showMediationDebugger();
    //   }
    // });
    await AppLovinAdManager.initialize();
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
      title: 'VidMeet',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
    );
  }
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

  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      print('Error checking onboarding status: $e');
      _onboardingCompleted = false;
    }
  }

  Future<void> _initializeApp() async {
    await ApiRepository.instance.initialize();

    await ApiRepository.instance.initialize();
    await _checkOnboardingStatus();

    if (mounted) setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 100));

    await _showAppOpenAdOnce();

    if (mounted) {
      setState(() {
        _isLoading = false;
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

    // Show main auth flow after ad
    return StreamBuilder<ApiUser?>(
      stream: ApiRepository.instance.auth.authStateChanges,
      builder: (context, snapshot) {
        // decide which screen to show after ad
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) return const MainAppScreen();
          return const AuthScreen();
        }
        // Still waiting for auth stream
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }

  bool _appOpenAdShown = false;
  Future<void> _showAppOpenAdOnce() async {
    if (_appOpenAdShown) return;
    _appOpenAdShown = true;

    await Future.delayed(const Duration(seconds: 1));

    final completer = Completer<void>();
    if (AppLovinAdManager.isAppOpenAvailable) {
      AppLovinAdManager.showAppOpenAd(onDismissed: () {
        debugPrint("ℹ️ AppOpen dismissed after show");
        completer.complete();
      });
    } else {
      debugPrint("⚠️ No AppOpen ad available yet");
      completer.complete();
    }

    return completer.future;
  }
}


Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService.handleNotificationClickPayload(jsonEncode(message.data));
}
