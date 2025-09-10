import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidmeet/widgets/rate_us_dialog.dart';
import 'package:vidmeet/widgets/app_update_dialog.dart';

class DialogManagerService {
  static final DialogManagerService _instance = DialogManagerService._internal();
  factory DialogManagerService() => _instance;
  DialogManagerService._internal();

  static const String _rateDialogShownKey = 'rate_dialog_shown';
  static const String _lastRatePromptKey = 'last_rate_prompt';
  static const String _appLaunchCountKey = 'app_launch_count';
  static const String _lastUpdateCheckKey = 'last_update_check';
  
  // Configuration
  static const int _minLaunchesForRating = 5;
  static const int _daysBetweenRatePrompts = 7;
  static const int _hoursBetweenUpdateChecks = 24;

  Future<void> initialize() async {
    await _incrementLaunchCount();
  }

  Future<void> _incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_appLaunchCountKey) ?? 0;
    await prefs.setInt(_appLaunchCountKey, currentCount + 1);
  }

  Future<bool> shouldShowRateDialog() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if user has already rated
    final hasRated = prefs.getBool(_rateDialogShownKey) ?? false;
    if (hasRated) return false;
    
    // Check launch count
    final launchCount = prefs.getInt(_appLaunchCountKey) ?? 0;
    if (launchCount < _minLaunchesForRating) return false;
    
    // Check if enough time has passed since last prompt
    final lastPrompt = prefs.getInt(_lastRatePromptKey) ?? 0;
    final daysSinceLastPrompt = DateTime.now().millisecondsSinceEpoch - lastPrompt;
    final daysDifference = daysSinceLastPrompt / (1000 * 60 * 60 * 24);
    
    return daysDifference >= _daysBetweenRatePrompts;
  }

  Future<void> showRateDialog(BuildContext context) async {
    final shouldShow = await shouldShowRateDialog();
    if (!shouldShow) return;

    if (context.mounted) {
      await RateUsDialog.show(context);
      await _markRatePromptShown();
    }
  }

  Future<void> _markRatePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRatePromptKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> markUserRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rateDialogShownKey, true);
  }

  Future<bool> shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
    final hoursSinceLastCheck = (DateTime.now().millisecondsSinceEpoch - lastCheck) / (1000 * 60 * 60);
    
    return hoursSinceLastCheck >= _hoursBetweenUpdateChecks;
  }

  Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    final shouldCheck = await shouldCheckForUpdate();
    if (!shouldCheck) return;

    try {
      final updateInfo = await AppUpdateDialog.checkForUpdate();
      if (updateInfo != null && updateInfo.hasUpdate && context.mounted) {
        await AppUpdateDialog.show(context, updateInfo);
      }
      
      await _markUpdateChecked();
    } catch (e) {
      debugPrint('Error checking for update: $e');
    }
  }

  Future<void> _markUpdateChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Call this method when app comes to foreground or on specific events
  Future<void> handleAppResume(BuildContext context) async {
    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(seconds: 1));
    
    if (context.mounted) {
      // Check for app updates first (higher priority)
      await checkAndShowUpdateDialog(context);
      
      // Then check for rate dialog (only if no update dialog was shown)
      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        await showRateDialog(context);
      }
    }
  }

  // Call this after significant user actions (video upload, profile update, etc.)
  Future<void> handleUserEngagement(BuildContext context) async {
    // Increased chance to show rate dialog after positive user engagement
    final prefs = await SharedPreferences.getInstance();
    final launchCount = prefs.getInt(_appLaunchCountKey) ?? 0;
    
    if (launchCount >= _minLaunchesForRating ~/ 2 && context.mounted) {
      await showRateDialog(context);
    }
  }

  Future<void> resetRatingPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rateDialogShownKey);
    await prefs.remove(_lastRatePromptKey);
  }

  Future<void> resetUpdateChecks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUpdateCheckKey);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rateDialogShownKey);
    await prefs.remove(_lastRatePromptKey);
    await prefs.remove(_appLaunchCountKey);
    await prefs.remove(_lastUpdateCheckKey);
  }

  // Statistics methods
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'launchCount': prefs.getInt(_appLaunchCountKey) ?? 0,
      'hasRated': prefs.getBool(_rateDialogShownKey) ?? false,
      'lastRatePrompt': prefs.getInt(_lastRatePromptKey) ?? 0,
      'lastUpdateCheck': prefs.getInt(_lastUpdateCheckKey) ?? 0,
    };
  }
}