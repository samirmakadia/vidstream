import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:flutter/services.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import '../../../helper/navigation_helper.dart';
import '../bottomsheet/comments_bottom_sheet.dart';
import '../bottomsheet/report_dialog.dart';
import '../../other_user_profile_screen.dart';
import '../../../utils/graphics.dart';
import '../../../widgets/custom_image_widget.dart';

class VideoActionsWidget extends StatefulWidget {
  final ApiUser user;
  final ApiVideo video;
  final bool isLiked;
  final VoidCallback onLikeToggle;
  final bool isLikeLoading;
  final void Function(ApiVideo video)? onVideoDeleted;
  final int likeCount;
  final void Function(int commentCount)? onCommentUpdated;
  final void Function(ApiVideo video)? onReported;
  final VoidCallback onFollowToggle;
  final bool isFollowLoading;
  final VoidCallback? onPauseRequested;
  final VoidCallback? onResumeRequested;

  const VideoActionsWidget({
    super.key,
    required this.user,
    required this.video,
    required this.isLiked,
    required this.onLikeToggle,
    this.isLikeLoading = false,
    this.onVideoDeleted, required this.likeCount,
    this.onCommentUpdated,
    this.onReported,
    required this.onFollowToggle,
    this.isFollowLoading = false, this.onPauseRequested, this.onResumeRequested,
  });

  @override
  State<VideoActionsWidget> createState() => _VideoActionsWidgetState();
}

class _VideoActionsWidgetState extends State<VideoActionsWidget> {
  bool _isSharing = false;

  Future<void> _showComments(BuildContext context) async {
    widget.onPauseRequested?.call();

    final updatedCommentCount = await  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(videoId: widget.video.id),
    );

    if (updatedCommentCount != null) {
      widget.onCommentUpdated?.call(updatedCommentCount);
    }
    widget.onResumeRequested?.call();
  }

  Future<bool> _ensureStoragePermission() async {
    if (Platform.isAndroid && (await _androidVersion()) <= 28) {
      var status = await Permission.storage.status;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
    }
    return true;
  }

  Future<int> _androidVersion() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  Future<void> _shareVideo(BuildContext context) async {
    final videoUrl = widget.video.videoUrl;
    const appLink = 'https://play.google.com/store/apps/details?id=com.vidmeet.app';

    try {
      widget.onPauseRequested?.call();

      final granted = await _ensureStoragePermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied.')),
        );
        widget.onResumeRequested?.call();
        return;
      }

      setState(() => _isSharing = true);
      final tempDir = Platform.isAndroid
          ? await getExternalCacheDirectories().then((dirs) => dirs!.first)
          : await getTemporaryDirectory();

      final filePath = '${tempDir.path}/${widget.video.id}.mp4';

      await Dio().download(videoUrl, filePath);
      final file = File(filePath);
      if (!await file.exists()) throw Exception('Failed to download video');

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Watch this awesome video on VidMeet!\n$appLink',
      );

    } catch (e, s) {
      print('❌ Error sharing video: $e');
      print('Stacktrace: $s');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share video. Please try again.')),
      );
    } finally {
      // ▶ Resume video after share or error
      widget.onResumeRequested?.call();
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _showVideoOptions(BuildContext context) async {
    widget.onPauseRequested?.call();

    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwner = currentUserId == widget.video.userId;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Video', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report as Spam', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, 'report'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'delete') {
      await _deleteVideo(context);
    } else if (result == 'report') {
      await _reportVideo(widget.video);
    } else {
      widget.onResumeRequested?.call();
    }
  }

  Future<void> _deleteVideo(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiRepository.instance.videos.deleteVideo(widget.video.id);
        widget.onVideoDeleted?.call(widget.video);
        Graphics.showTopDialog(
          context,
          "Success!",
          'Video deleted successfully',
        );
      } catch (e) {
        if (context.mounted) {
          Graphics.showTopDialog(
            context,
            "Error!",
            'Failed to delete video: $e',
            type: ToastType.error,
          );
        }
      }
    }
    widget.onResumeRequested?.call();
  }

  Future<void> _reportVideo(Video video) async {
    final reasons = {
      'Spam': 'spam',
      'Inappropriate content': 'inappropriate_content',
      'Harassment': 'harassment',
      'Copyright': 'copyright',
      'Fake Account': 'fake_account',
      'Other': 'other',
    };

    await showDialog(
      context: context,
      builder: (_) => ReportDialog(
        scaffoldContext: context,
        title: 'Report Video',
        reasons: reasons,
        isDescriptionRequired: false,
        onCancel: () {
          widget.onResumeRequested?.call();
        },
        onSubmit: ({required reason, String? description}) async {
          return await handleReport(
            targetId: video.id,
            targetType: 'Video',
            reason: reason,
            description: description,
            onSuccess: () {
              widget.onReported?.call(video);
            },
          );
        },
      ),
    );
  }

  Future<String> handleReport({
    required String targetId,
    required String targetType,
    required String reason,
    String? description,
    VoidCallback? onSuccess,
  }) async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;

    if (currentUserId == null) {
      Graphics.showTopDialog(
        context,
        "Error",
        'User is not logged in. Cannot submit report.',
        type: ToastType.error,
      );
      return '';
    }

    try {
      final result = await ApiRepository.instance.reports.reportContent(
        reporterId: currentUserId,
        targetId: targetId,
        targetType: targetType,
        reason: reason,
        description: description,
      );
      Graphics.showToast(
        message: result,
        isSuccess: result.toLowerCase().contains('success'),
      );
      if (result.toLowerCase().contains('success')) {
        onSuccess?.call();
      }
      else {
        widget.onResumeRequested?.call();
      }

      return result;
    } catch (e) {
      Graphics.showTopDialog(
        context,
        "Error",
        'Failed to submit report: $e',
        type: ToastType.error,
      );
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () {
                NavigationHelper.navigateWithAd(
                  context: context,
                  destination: OtherUserProfileScreen(
                    userId: widget.user.id,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.5),
                    width: 0.5, // border width
                  ),
                ),
                child: widget.user.profileImageUrl != null && widget.user.profileImageUrl!.isNotEmpty
                    ? CustomImageWidget(
                  imageUrl: widget.user.profileImageUrl ?? '',
                  height: 44,
                  width: 44,
                  cornerRadius: 22,
                  borderWidth: 0,
                  fit: BoxFit.cover,
                ) :
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child:  Icon(Icons.person, size: 20, color: Colors.white)
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.isFollowLoading ? null : widget.onFollowToggle,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.user.isFollow ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: widget.isFollowLoading
                        ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(
                      widget.user.isFollow ? Icons.check : Icons.add,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Like Button
        _buildActionButton(
          context,
          icon: widget.isLiked ? Icons.favorite : Icons.favorite_outline,
          color: widget.isLiked ? Colors.red : Colors.white,
          count: widget.likeCount,
          onTap: widget.isLikeLoading ? () {} : widget.onLikeToggle,
          isLoading: widget.isLikeLoading,
        ),

        const SizedBox(height: 12),

        // Comment Button
        _buildActionButton(
          context,
          icon: Icons.comment_outlined,
          color: Colors.white,
          count: widget.video.commentsCount,
          onTap: () => _showComments(context),
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          context,
          icon: Icons.share_outlined,
          color: Colors.white,
          count: null,
          onTap: _isSharing ? () {} : () async => await _shareVideo(context),
          isLoading: _isSharing,
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          context,
          icon: Icons.more_horiz,
          color: Colors.white,
          count: null,
          onTap: () => _showVideoOptions(context),
        ),

        const SizedBox(height: 12),

        // Views Count
        Column(
          children: [
            Icon(
              Icons.visibility_outlined,
              color: Colors.white.withValues(alpha: 0.8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              _formatCount(widget.video.viewsCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required int? count,
        required VoidCallback onTap,
        bool isLoading = false,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatCount(count),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }


  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}



