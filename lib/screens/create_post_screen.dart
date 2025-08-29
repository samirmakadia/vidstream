import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../models/api_models.dart';
import '../services/socket_manager.dart';
import '../services/video_service.dart';
import '../widgets/custom_image_widget.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> with TickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<String> _availableTags = [
    'funny', 'comedy', 'emotional', 'inspiring', 'tutorial', 'music',
    'dance', 'cooking', 'travel', 'lifestyle', 'pets', 'gaming'
  ];

  File? _selectedVideo;
  bool _isUploading = false;
  bool _isUploadingVideo = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  ApiCommonFile? _uploadedFile;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _isUploadingVideo = true;
        });

        // Immediately upload the selected video
        await _uploadCommonFile(_selectedVideo!.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture video: $e');
    } finally {
      setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _isUploadingVideo = true;
        });

        await _uploadCommonFile(_selectedVideo!.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video: $e');
    } finally {
      setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _pickVideoFromFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedVideo = File(result.files.single.path!);
          _isUploadingVideo = true;
        });

        await _uploadCommonFile(_selectedVideo!.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video file: $e');
    } finally {
      setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _uploadCommonFile(String filePath) async {
    try {
      final videoService = VideoService();

      final uploadedFile = await videoService.uploadCommonFile(
        filePath: filePath,
        type: 'post',
      );

      if (uploadedFile == null) {
        _showErrorSnackBar("Failed to upload video to server");
        return;
      }

      setState(() {
        _uploadedFile = uploadedFile;
        print('Uploaded file object: $_uploadedFile');
      });
    } catch (e) {
      _showErrorSnackBar('Failed to upload video: $e');
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else if (_selectedTags.length < 5) {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _uploadVideo() async {
    if (_uploadedFile == null) {
      _showErrorSnackBar('Please select a video first');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please add a description');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final videoService = VideoService();

      final uploadedVideo = await videoService.uploadVideo(
        videoPath: _uploadedFile!.url,
        thumbnailPath: _uploadedFile!.thumbnailUrl,
        duration: _uploadedFile!.duration,
        title: "Untitled",
        description: _descriptionController.text.trim(),
        // category: _uploadedFile!.category ?? 'general',
        tags: _selectedTags,
        isPublic: true,
      );
      print('Uploaded video object: $uploadedVideo');

      if (uploadedVideo != null && mounted) {
        eventBus.fire('newVideo');
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar("Failed to upload video metadata");
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload video: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text('Create Post'),
        actions: [
          if (_selectedVideo != null)
            TextButton(
              onPressed: _isUploading ? null : _uploadVideo,
              child: _isUploading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'Share',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: _selectedVideo == null ? _buildVideoSelectionView() : _buildVideoEditView(),
      ),
    );
  }

  Widget _buildVideoSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.6),
          ),

          const SizedBox(height: 24),

          Text(
            'Share Your Story',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            'Choose a video to share with the world',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // Video selection buttons
          Column(
            children: [
              _buildSelectionButton(
                icon: Icons.videocam,
                title: 'Record Video',
                subtitle: 'Capture a new video',
                onTap: _pickVideoFromCamera,
              ),

              const SizedBox(height: 16),

              _buildSelectionButton(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                subtitle: 'Select from your photos',
                onTap: _pickVideoFromGallery,
              ),

              const SizedBox(height: 16),

              _buildSelectionButton(
                icon: Icons.folder_open,
                title: 'Browse Files',
                subtitle: 'Pick any video file',
                onTap: _pickVideoFromFiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (_uploadedFile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenVideoPlayer(
                      videoUrl: _uploadedFile!.url,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  if(_uploadedFile != null)
                  CustomImageWidget(
                    imageUrl: _uploadedFile!.thumbnailUrl ?? '',
                    height: double.infinity,
                    width:double.infinity,
                    cornerRadius: 12,
                    borderWidth: 0,
                    fit: BoxFit.cover,
                  ),
                  _isUploadingVideo
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      :
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedVideo = null;
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Description Input
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Tell us about your video...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tags Section
          Text(
            'Tags',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Select up to 5 tags (${_selectedTags.length}/5)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}


class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController,
            autoPlay: true,
            looping: false,
            allowFullScreen: true,
            allowPlaybackSpeedChanging: true,
          );
        });
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
