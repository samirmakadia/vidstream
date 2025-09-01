import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/screens/auth_screen.dart';
import 'package:vidstream/screens/blocked_users_screen.dart';
import 'package:vidstream/screens/my_reports_screen.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';
import 'package:vidstream/storage/message_storage_drift.dart';
import 'package:vidstream/widgets/rate_us_dialog.dart';
import 'package:vidstream/widgets/app_update_dialog.dart';
import 'package:vidstream/services/dialog_manager_service.dart';
import 'package:vidstream/services/notification_service.dart';
import '../services/video_service.dart';
import '../widgets/common_app_dialog.dart';
import '../widgets/common_snackbar.dart';
import '../widgets/custom_image_widget.dart';

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
Email: support@vidstream.com
Response time: 24-48 hours

Follow us:
Twitter: @VidStreamApp
Instagram: @VidStreamOfficial''',
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
            : ListView(
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BlockedUsersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsItem(
                    icon: Icons.report,
                    title: 'My Reports (Spam)',
                    subtitle: 'View your submitted reports',
                    onTap: () {
                      if (_currentUser?.id != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MyReportsScreen(
                              currentUserId: _currentUser!.id,
                            ),
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
                    title: 'Rate VidStream',
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
                          'VidStream',
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

class EditProfileBottomSheet extends StatefulWidget {
  final ApiUser? currentUser;
  final VoidCallback onProfileUpdated;

  const EditProfileBottomSheet({
    super.key,
    this.currentUser,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends State<EditProfileBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  String? _avatarImageUrl;
  String? _bannerImageUrl;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser?.displayName ?? '');
    _bioController = TextEditingController(text: widget.currentUser?.bio ?? '');
    _avatarImageUrl = widget.currentUser?.profileImageUrl;
    _bannerImageUrl = widget.currentUser?.bannerImageUrl;
    _selectedDateOfBirth = widget.currentUser?.dateOfBirth;
    _selectedGender = widget.currentUser?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }


  Future<void> _pickAndUploadImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: type == 'banner' ? 1200 : 400,
        maxHeight: type == 'banner' ? 400 : 400,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isLoading = true);
      setState(() {
        if (type == 'avatar') {
          _avatarImageUrl = image.path;
        } else {
          _bannerImageUrl = image.path;
        }
      });
      final uploadedFile = await _uploadCommonFile(image.path);

      if (uploadedFile != null) {
        setState(() {
          if (type == 'avatar') {
            _avatarImageUrl = uploadedFile.url;
          } else {
            _bannerImageUrl = uploadedFile.url;
          }
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<ApiCommonFile?> _uploadCommonFile(String filePath) async {
    try {
      final videoService = VideoService();

      final uploadedFile = await videoService.uploadCommonFile(
        filePath: filePath,
        type: 'image',
      );

      if (uploadedFile == null) {
        _showErrorSnackBar("Failed to upload file to server");
        return null;
      }
      return uploadedFile;
    } catch (e) {
      _showErrorSnackBar('Failed to upload file: $e');
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showImagePickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Update ${type == 'avatar' ? 'Profile Picture' : 'Banner'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(type);
              },
            ),
            if (type == 'avatar' ? _avatarImageUrl != null : _bannerImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Remove ${type == 'avatar' ? 'Profile Picture' : 'Banner'}',
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (type == 'avatar') {
                      _avatarImageUrl = null;
                    } else {
                      _bannerImageUrl = null;
                    }
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: Colors.grey[900]!,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = pickedDate;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Display name cannot be empty');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = widget.currentUser?.id;
      if (userId != null) {
        
        final updateData = {
          'displayName': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'profileImageUrl': _avatarImageUrl,
          'bannerImageUrl': _bannerImageUrl,
          'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
          'gender': _selectedGender,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        
        print('Update data: $updateData');

        await ApiRepository.instance.api.updateUserProfile(
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
          gender: _selectedGender?.isNotEmpty == true ? _selectedGender : null,
          dateOfBirth: _selectedDateOfBirth,
          profileImageUrl: _avatarImageUrl ?? '',
          bannerImageUrl: _bannerImageUrl ?? '',
        );
            
        print('Profile update completed successfully');
      } else {
        print('Error: userId is null');
        _showErrorSnackBar('User ID is missing');
        return;
      }
      
      widget.onProfileUpdated();
      Navigator.of(context).pop(true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Profile update error: $e');
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Edit Profile',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Section
                  Text(
                    'Banner Image',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _showImagePickerOptions('banner'),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[700]!,
                              width: 1,
                            ),
                          ),
                          child: _bannerImageUrl != null && _bannerImageUrl!.isNotEmpty
                              ? CustomImageWidget(
                            imageUrl: _bannerImageUrl ?? '',
                            height: 120,
                            width: double.infinity,
                            cornerRadius: 12,
                            fit: BoxFit.cover,
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Banner Image',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -10,
                        right: -10,
                        child: GestureDetector(
                          onTap: () => _showImagePickerOptions('banner'),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Avatar Section
                  Text(
                    'Profile Picture',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () => _showImagePickerOptions('avatar'),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[900],
                              border: Border.all(
                                color: Colors.grey[700]!,
                                width: 2,
                              ),
                            ),
                            child: _avatarImageUrl != null &&
                                _avatarImageUrl!.isNotEmpty
                                ? CustomImageWidget(
                              imageUrl: _avatarImageUrl ?? '',
                              height: 100,
                              width: 100,
                              cornerRadius: 50,
                              fit: BoxFit.cover,
                            )
                                : Icon(
                              Icons.add_a_photo,
                              color: Colors.grey[400],
                              size: 32,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showImagePickerOptions('avatar'),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Display Name Field
                  Text(
                    'Display Name',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter your display name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bio Field
                  Text(
                    'Bio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell us about yourself...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date of Birth Field
                  Text(
                    'Date of Birth',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDateOfBirth,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDateOfBirth != null
                                ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                                : 'Select your date of birth',
                            style: TextStyle(
                              color: _selectedDateOfBirth != null ? Colors.white : Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gender Field
                  Text(
                    'Gender',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        hint: Text(
                          'Select gender',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        isExpanded: true,
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey[400],
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'male',
                            child: Row(
                              children: [
                                Icon(Icons.male, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text('Male'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Row(
                              children: [
                                Icon(Icons.female, color: Colors.pink, size: 20),
                                SizedBox(width: 8),
                                Text('Female'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Row(
                              children: [
                                Icon(Icons.person, color: Colors.purple, size: 20),
                                SizedBox(width: 8),
                                Text('Other'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalDocumentViewer extends StatefulWidget {
  final String title;
  final String fileName;

  const LegalDocumentViewer({
    super.key,
    required this.title,
    required this.fileName,
  });

  @override
  State<LegalDocumentViewer> createState() => _LegalDocumentViewerState();
}

class _LegalDocumentViewerState extends State<LegalDocumentViewer> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final content = await rootBundle.loadString('legal/${widget.fileName}');
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  List<Widget> _parseMarkdownContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      
      // Handle headers
      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Text(
              line.substring(3),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Handle bullet points
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // Handle bold text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line.substring(2, line.length - 2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.trim().isNotEmpty) {
        // Regular paragraph text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _loadDocument();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _parseMarkdownContent(_content),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}