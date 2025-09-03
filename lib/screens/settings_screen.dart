import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/screens/auth_screen.dart';
import 'package:vidstream/screens/blocked_users_screen.dart';
import 'package:vidstream/screens/my_reports_screen.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/setting/bottomsheet/edit_profile_bottom_sheet.dart';
import 'package:vidstream/screens/setting/bottomsheet/legal_document_viewer.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';
import 'package:vidstream/storage/message_storage_drift.dart';
import 'package:vidstream/widgets/rate_us_dialog.dart';
import 'package:vidstream/widgets/app_update_dialog.dart';
import 'package:vidstream/services/dialog_manager_service.dart';
import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../widgets/common_app_dialog.dart';
import '../widgets/common_snackbar.dart';
import '../widgets/professional_bottom_ad.dart';

class SettingsScreen extends StatefulWidget {
  final ApiUser? currentUser;

  const SettingsScreen({
    super.key,
    this.currentUser,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  ApiUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _loadUserProfile();
  }

  Future<void> _signOut() async {
    bool confirmed = await CommonDialog.showConfirmationDialog(
      context: context,
      title: "Sign Out",
      content:
      "Are you sure you want to sign out of your account?",
      confirmText: "Sign Out",
      confirmColor: Colors.orange,
    );
    if (!confirmed) return;
    setState(() => _isLoading = true);
    try {
      await ApiRepository.instance.auth.signOut();
      await MessageDatabase.instance.clearMessagesTable();
      await ConversationDatabase.instance.clearTable();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      AppSnackBar.showError(context, 'Failed to sign out: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    bool confirmed = await CommonDialog.showConfirmationDialog(
      context: context,
      title: "Delete Account",
      content:
      "Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.",
      confirmText: "Delete",
      confirmColor: Colors.red,
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await ApiRepository.instance.auth.deleteAccount();
      await MessageDatabase.instance.clearMessagesTable();
      await ConversationDatabase.instance.clearTable();
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppSnackBar.showError(context, 'Failed to delete account: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditProfileBottomSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileBottomSheet(
        currentUser: _currentUser,
        onProfileUpdated: () {
          _loadUserProfile();
        },
      ),
    );
  }

  void _showLegalDocument(String title, String fileName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegalDocumentViewer(
        title: title,
        fileName: fileName,
      ),
    );
  }

  void _showPrivacyPolicy() {
    _showLegalDocument('Privacy Policy', 'privacy_policy.md');
  }

  void _showTermsAndConditions() {
    _showLegalDocument('Terms & Conditions', 'terms_and_conditions.md');
  }

  void _showCommunityGuidelines() {
    _showLegalDocument('Community Guidelines', 'community_guidelines.md');
  }

  void _showLegalComplianceGuide() {
    _showLegalDocument('Legal Compliance Guide', 'legal_compliance_guide.md');
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null) {
        final user = await ApiRepository.instance.auth.getUserProfile(currentUserId);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showHelpAndSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '''VidMeet Help & Support

Need help? We're here for you!

Frequently Asked Questions:

Q: How do I upload a video?
A: Tap the + button on the home screen, select or record a video, add a description, and post!

Q: How do I change my profile picture?
A: Go to Settings → Edit Profile and tap on your profile picture.

Q: How do I report inappropriate content?
A: Tap and hold on any video to see the report option.

Q: How do I block a user?
A: Go to their profile and tap the block button, or manage blocked users in Settings.

Q: How do I delete my account?
A: Go to Settings → Delete Account. Note: This action cannot be undone.

Contact Support:
Email: support@vidmeet.com
Response time: 24-48 hours

Follow us:
Twitter: @VidMeetApp
Instagram: @VidMeetOfficial''',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRateUsDialog() async {
    await RateUsDialog.show(context);
    await DialogManagerService().markUserRated();
  }

  Future<void> _checkForUpdates() async {
    try {
      AppSnackBar.showLoading(context, "Checking for updates...");
      
      final updateInfo = await AppUpdateDialog.checkForUpdate();
      if (updateInfo != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (updateInfo.hasUpdate) {
            await AppUpdateDialog.show(context, updateInfo);
          } else {
            AppSnackBar.showSuccess(context, 'You\'re using the latest version!');
          }
        }
      } else {
        AppSnackBar.showError(context, 'Unable to check for updates');
      }
    } catch (e) {
      AppSnackBar.showError(context, 'Error checking for updates: $e');
    }
  }

  Future<void> _resetOnboarding() async {
    try {
      AppSnackBar.showLoading(context, "Resetting onboarding...");
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        AppSnackBar.showSuccess(context, "Onboarding reset! Restart the app to see onboarding.");
      }
    } catch (e) {
      AppSnackBar.showError(context, 'Failed to reset onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(true);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          title: const Text('Settings'),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SafeArea(
              child: ProfessionalBottomAd(
                child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Profile Section
                      _buildSectionHeader('Profile'),
                      _buildSettingsItem(
                        icon: Icons.edit,
                        title: 'Edit Profile',
                        subtitle: 'Update your name, bio, and photos',
                        onTap: _showEditProfileBottomSheet,
                      ),
                      const SizedBox(height: 20),
                
                      // Privacy Section
                      _buildSectionHeader('Privacy & Safety'),
                      _buildSettingsItem(
                        icon: Icons.block,
                        title: 'Blocked Users',
                        subtitle: 'Manage blocked accounts',
                        onTap: () {
                          NavigationHelper.navigateWithAd(
                            context: context,
                            destination: const BlockedUsersScreen(),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.report,
                        title: 'My Reports (Spam)',
                        subtitle: 'View your submitted reports',
                        onTap: () {
                          if (_currentUser?.id != null) {
                            NavigationHelper.navigateWithAd(
                              context: context,
                              destination: MyReportsScreen(
                                currentUserId: _currentUser!.id,
                              ),
                            );
                          } else {
                            AppSnackBar.showError(context, 'User not found');
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                
                
                      // Support Section
                      _buildSectionHeader('Support'),
                      _buildSettingsItem(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact us',
                        onTap: _showHelpAndSupport,
                      ),
                      _buildSettingsItem(
                        icon: Icons.star,
                        title: 'Rate VidMeet',
                        subtitle: 'Share your experience with us',
                        onTap: _showRateUsDialog,
                      ),
                      _buildSettingsItem(
                        icon: Icons.system_update,
                        title: 'Check for Updates',
                        subtitle: 'See if a new version is available',
                        onTap: _checkForUpdates,
                      ),
                      const SizedBox(height: 20),
                
                
                      // Legal Section
                      _buildSectionHeader('Legal'),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: _showPrivacyPolicy,
                      ),
                      _buildSettingsItem(
                        icon: Icons.description,
                        title: 'Terms & Conditions',
                        subtitle: 'Our terms of service',
                        onTap: _showTermsAndConditions,
                      ),
                      _buildSettingsItem(
                        icon: Icons.group,
                        title: 'Community Guidelines',
                        subtitle: 'Rules for our community',
                        onTap: _showCommunityGuidelines,
                      ),
                      _buildSettingsItem(
                        icon: Icons.gavel,
                        title: 'Legal Compliance Guide',
                        subtitle: 'Legal requirements and compliance',
                        onTap: _showLegalComplianceGuide,
                      ),
                      const SizedBox(height: 20),
                
                      // Account Section
                      _buildSectionHeader('Account'),
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out of your account',
                        onTap: _signOut,
                        textColor: Colors.orange,
                      ),
                      _buildSettingsItem(
                        icon: Icons.delete_forever,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        onTap: _deleteAccount,
                        textColor: Colors.red,
                      ),
                      const SizedBox(height: 40),
                
                      // App Info
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'VidMeet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Version 1.0.0',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
            ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    final itemColor = textColor ?? Colors.white;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (textColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: textColor ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: itemColor.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: itemColor.withValues(alpha: 0.5),
          size: 16,
        ),
        onTap: onTap,
        tileColor: Colors.grey[900]?.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
