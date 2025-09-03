import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vidstream/screens/setting/bottomsheet/legal_document_viewer.dart';
import 'package:vidstream/screens/settings_screen.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/screens/main_app_screen.dart';
import 'package:vidstream/theme.dart';
import 'package:flutter/gestures.dart';

import '../utils/graphics.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _isAppleSignInAvailable = false;
  late final GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: ['email'],
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
    _checkAppleAvailability();
  }
  Future<void> _checkAppleAvailability() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (mounted) {
        setState(() => _isAppleSignInAvailable = isAvailable);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAppleSignInAvailable = false);
      }
    }
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestAppleLogin(String? idToken, String? firstName, String? lastName) async {
    if (idToken == null) {
      Graphics.showTopDialog(context, 'Error!', 'Apple sign-in failed', type: ToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiRepository.instance.auth.signInWithAppleToken(token: idToken);
      if (result != null && mounted) {
        await ApiRepository.instance.auth.saveSession(result);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainAppScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple sign in failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiRepository.instance.auth.signInAsGuest();
      if (result != null && mounted) {
        await ApiRepository.instance.auth.saveSession(result);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainAppScreen()),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Guest sign in was cancelled or failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e,s) {
      print(e);
      print(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guest sign in failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        await _requestGoogleLogin(googleAuth.idToken, googleAuth.accessToken);
      } else {
        Graphics.showTopDialog(context, 'Opps!', 'Google sign-in cancelled', type: ToastType.error);
      }
    } catch (error,s) {
      print(error);
      print(s);
      Graphics.showTopDialog(context, 'Error!', 'Error signing in with Google: $error', type: ToastType.error);
    }
  }

  Future<void> _requestGoogleLogin(String? idToken, String? accessToken) async {
    print('idToken: $idToken');
    if (idToken == null || accessToken == null) {
      Graphics.showTopDialog(context, 'Error!', 'Google sign-in failed', type: ToastType.error);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiRepository.instance.auth.signInWithGoogleToken(idToken: idToken);
      if (result != null && mounted) {
        await ApiRepository.instance.auth.saveSession(result);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainAppScreen()),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Google sign in was cancelled or failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e,s) {
      print(e);
      print(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

  }

  Future<void> _signInWithApple() async {
    try {
      if (!_isAppleSignInAvailable) {
        Graphics.showTopDialog(context, 'Error!', 'Apple Sign-In is not available on this device.', type: ToastType.error);
        return;
      }
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.fullName,
          AppleIDAuthorizationScopes.email,
        ],
      );
      await _requestAppleLogin(
        credential.identityToken,
        credential.givenName ?? '',
        credential.familyName ?? '',
      );
    } catch (error) {
      Graphics.showTopDialog(context, 'Error!', 'Apple sign-in failed: $error', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // App Logo and Title
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            "assets/icon/white_logo.png",
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            'VidMeet',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share your moments, connect with the world',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Sign in buttons
                    Column(
                      children: [
                        // Google Sign In
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            icon: Icon(
                              Icons.g_mobiledata,
                              size: 32,
                              color: Colors.black,
                            ),
                            label: Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Apple Sign In (only on iOS)
                        if (_isAppleSignInAvailable) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _signInWithApple,
                              icon: Icon(
                                Icons.apple,
                                size: 24,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Continue with Apple',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Guest Sign In
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInAsGuest,
                            icon: Icon(
                              Icons.person_outline,
                              size: 24,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Continue as Guest',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Loading indicator
                    if (_isLoading)
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),

                    const SizedBox(height: 20),

                    // Terms and Privacy
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        children: [
                          const TextSpan(text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 1),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // ✅ Show your legal bottom sheet for Terms
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const LegalDocumentViewer(
                                    title: 'Terms & Conditions',
                                    fileName: 'terms_and_conditions.md',
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: '\n and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 1),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // ✅ Show your legal bottom sheet for Privacy
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => const LegalDocumentViewer(
                                    title: 'Privacy Policy',
                                    fileName: 'privacy_policy.md',
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}