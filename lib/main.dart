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
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services (non-blocking)
  _initializeServices();
  
  runApp(const MyApp());
}

// Initialize services in the background
void _initializeServices() async {
  try {
    await ServiceLocator.initialize();
    await ApiRepository.instance.initialize();
    await NotificationService().initialize();
    await DialogManagerService().initialize();
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
      themeMode: ThemeMode.system,
      navigatorKey: ServiceLocator().navigatorKey,
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
    _checkOnboardingStatus();
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
      
      if (mounted) {
        setState(() {
          _onboardingCompleted = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
      if (mounted) {
        setState(() {
          _onboardingCompleted = false;
          _isLoading = false;
        });
      }
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
        // if (snapshot.connectionState == ConnectionState.waiting) {
        //   return const Scaffold(
        //     backgroundColor: Colors.black,
        //     body: Center(
        //       child: CircularProgressIndicator(color: Colors.white),
        //     ),
        //   );
        // }
        
        if (snapshot.hasData) {
          return const MainAppScreen();
        }
        
        return const AuthScreen();
      },
    );
  }
}

