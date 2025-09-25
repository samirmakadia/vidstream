import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/api_models.dart';
import '../../../repositories/api_repository.dart';
import '../../../services/socket_manager.dart';
import '../../../services/video_service.dart';
import '../../../utils/graphics.dart';
import '../../../widgets/custom_image_widget.dart';
import '../../../widgets/professional_bottom_ad.dart';

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
    setData();
  }

  void setData() {
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
      Graphics.showTopDialog(
        context,
        "Error!",
        'Failed to pick image: $e',
        type: ToastType.error,
      );
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
        Graphics.showTopDialog(
          context,
          "Error!",
          "Failed to upload file to server",
          type: ToastType.error,
        );
        return null;
      }
      return uploadedFile;
    } catch (e) {
      Graphics.showTopDialog(
        context,
        "Error!",
        'Failed to upload file: $e',
        type: ToastType.error,
      );
      return null;
    }
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
      Graphics.showTopDialog(
        context,
        "Error!",
        'Display name cannot be empty',
        type: ToastType.error,
      );
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
        eventBus.fire({
          'type': 'updatedVideo',
          'source': 'fromOther',
        });
        print('Profile update completed successfully');
      } else {
        print('Error: userId is null');
        Graphics.showTopDialog(
          context,
          "Error!",
          'User ID is missing',
          type: ToastType.error,
        );
        return;
      }

      widget.onProfileUpdated();
      Navigator.of(context).pop(true);

      Graphics.showTopDialog(
        context,
        "Success!",
        'Profile updated successfully!',
      );
    } catch (e) {
      print('Profile update error: $e');
      Graphics.showTopDialog(
        context,
        "Error!",
        'Failed to update profile: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildBody(scrollController),
                _buildSaveButton(),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
      ],
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    return Expanded(
      child: ProfessionalBottomAd(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Section
              _sectionTitle('Banner Image'),
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
                    top: 0,
                    right: 0,
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

              _sectionTitle('Profile Picture'),
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
                        child: _avatarImageUrl != null && _avatarImageUrl!.isNotEmpty
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

              _sectionTitle('Display Name'),
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

              _sectionTitle('Bio'),
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

              _sectionTitle('Date of Birth'),
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
                      Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
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

              _sectionTitle('Gender'),
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
                    hint: Text('Select gender', style: TextStyle(color: Colors.grey[400])),
                    isExpanded: true,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
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
    );

  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
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
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

}