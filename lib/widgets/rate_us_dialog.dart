import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/graphics.dart';

class RateUsDialog extends StatefulWidget {
  const RateUsDialog({super.key});

  @override
  State<RateUsDialog> createState() => _RateUsDialogState();

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => const RateUsDialog(),
    );
  }
}

class _RateUsDialogState extends State<RateUsDialog> with TickerProviderStateMixin {
  int selectedRating = 0;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onStarTap(int rating) {
    setState(() {
      selectedRating = rating;
    });
    _scaleController.reset();
    _scaleController.forward();
  }

  Future<void> _handleRating() async {
    if (selectedRating == 0) return;

    if (selectedRating >= 4) {
      // Good rating - redirect to app store
      await _openAppStore();
    } else {
      // Low rating - show feedback option
      _showFeedbackDialog();
    }
  }

  Future<void> _openAppStore() async {
    // Replace with your actual app store URLs
    const androidUrl = 'https://play.google.com/store/apps/details?id=com.vidmeet.app';
    const iosUrl = 'https://apps.apple.com/app/vidmeet/id123456789';
    
    try {
      final Uri url;
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        url = Uri.parse(iosUrl);
      } else {
        url = Uri.parse(androidUrl);
      }
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) {
          Navigator.of(context).pop();
          _showThankYouSnackBar();
        }
      }
    } catch (e) {
      debugPrint('Error opening app store: $e');
    }
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Help us improve!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'We\'re sorry to hear you\'re not completely satisfied. Would you like to share your feedback with us?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              _openFeedbackEmail();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Send Feedback',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFeedbackEmail() async {
    final Uri emailUrl = Uri(
      scheme: 'mailto',
      path: 'feedback@vidmeet.com',
      query: 'subject=VidMeet App Feedback&body=Please share your feedback here...',
    );

    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl);
      }
    } catch (e) {
      debugPrint('Error opening email: $e');
    }
  }

  void _showThankYouSnackBar() {
    Graphics.showTopDialog(
      context,
      "Success!",
      'Thank you for your rating!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          // backgroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 10,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Icon and Title
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Rate VidMeet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  'How would you rate your experience?',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isSelected = starIndex <= selectedRating;
                    
                    return GestureDetector(
                      onTap: () => _onStarTap(starIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          size: 32,
                          color: isSelected
                              ? Colors.amber
                              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                
                // Rating Description
                if (selectedRating > 0) ...[
                  AnimatedOpacity(
                    opacity: selectedRating > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getRatingDescription(selectedRating),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Maybe Later',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedRating > 0 ? _handleRating : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: selectedRating > 0 ? 5 : 0,
                        ),
                        child: Text(
                          selectedRating >= 4 ? 'Rate on Store' : 'Submit',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return 'We\'re sorry to hear that. Your feedback helps us improve.';
      case 2:
        return 'Thank you for your honesty. We\'d love to know how we can do better.';
      case 3:
        return 'Thanks for the feedback. We\'re working to make VidMeet even better!';
      case 4:
        return 'Great! We\'re glad you\'re enjoying VidMeet.';
      case 5:
        return 'Awesome! Thank you for loving VidMeet!';
      default:
        return '';
    }
  }
}