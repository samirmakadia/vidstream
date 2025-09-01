import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:flutter/services.dart';
import 'package:vidstream/repositories/api_repository.dart';
import '../../../services/socket_manager.dart';
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

  Future<void> _showComments(BuildContext context) async {
    widget.onPauseRequested?.call();

    final updatedCommentCount = await  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(videoId: widget.video.id),
    );

    if (updatedCommentCount != null) {
      setState(() {
        widget.onCommentUpdated?.call(updatedCommentCount);
      });
    }
    widget.onResumeRequested?.call();
  }

  void _shareVideo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'Check out this video on VidStream!'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showVideoOptions(BuildContext context) {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwner = currentUserId == widget.video.userId;

    showModalBottomSheet(
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
                  onTap: () {
                    Navigator.pop(context);
                    _deleteVideo(context);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.orange),
                  title: const Text('Report as Spam', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _reportVideo(widget.video);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
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
        eventBus.fire('newVideo');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
      Graphics.showToast(
        message: 'User is not logged in. Cannot submit report.',
        isSuccess: false,
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

      return result;
    } catch (e) {
      Graphics.showToast(
        message: 'Failed to submit report: $e',
        isSuccess: false,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfileScreen(
                      userId: widget.user.id,
                    ),
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
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: widget.user.isFollow ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: widget.isFollowLoading
                        ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(
                      widget.user.isFollow ? Icons.check : Icons.add,
                      size: 11,
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

        // Share Button
        _buildActionButton(
          context,
          icon: Icons.share_outlined,
          color: Colors.white,
          count: null,
          onTap: () => _shareVideo(context),
        ),

        const SizedBox(height: 12),

        // More Options Button
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
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
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



