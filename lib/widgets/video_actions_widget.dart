import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:flutter/services.dart';
import 'package:vidstream/services/comment_service.dart';
import 'package:vidstream/services/like_service.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../utils/graphics.dart';

class VideoActionsWidget extends StatefulWidget {
  final ApiVideo video;
  final bool isLiked;
  final VoidCallback onLikeToggle;
  final bool isLikeLoading;
  final VoidCallback? onVideoDeleted;
  final int likeCount;
  final void Function(int commentCount)? onCommentUpdated;
  final void Function(ApiVideo video)? onReported;

  const VideoActionsWidget({
    super.key,
    required this.video,
    required this.isLiked,
    required this.onLikeToggle,
    this.isLikeLoading = false,
    this.onVideoDeleted, required this.likeCount,
    this.onCommentUpdated,
    this.onReported,
  });

  @override
  State<VideoActionsWidget> createState() => _VideoActionsWidgetState();
}

class _VideoActionsWidgetState extends State<VideoActionsWidget> {

  Future<void> _showComments(BuildContext context) async {
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onVideoDeleted?.call();
        }
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
      'Violence': 'violence',
      'Copyright violation': 'copyright_violation',
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
        // Like Button
        _buildActionButton(
          context,
          icon: widget.isLiked ? Icons.favorite : Icons.favorite_outline,
          color: widget.isLiked ? Colors.red : Colors.white,
          count: widget.likeCount,
          onTap: widget.isLikeLoading ? () {} : widget.onLikeToggle,
          isLoading: widget.isLikeLoading,
        ),

        const SizedBox(height: 20),

        // Comment Button
        _buildActionButton(
          context,
          icon: Icons.comment_outlined,
          color: Colors.white,
          count: widget.video.commentsCount,
          onTap: () => _showComments(context),
        ),

        const SizedBox(height: 20),

        // Share Button
        _buildActionButton(
          context,
          icon: Icons.share_outlined,
          color: Colors.white,
          count: null,
          onTap: () => _shareVideo(context),
        ),

        const SizedBox(height: 20),

        // More Options Button
        _buildActionButton(
          context,
          icon: Icons.more_horiz,
          color: Colors.white,
          count: null,
          onTap: () => _showVideoOptions(context),
        ),

        const SizedBox(height: 20),

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
            padding: const EdgeInsets.all(8),
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
            const SizedBox(height: 4),
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


class CommentsBottomSheet extends StatefulWidget {
  final String videoId;

  const CommentsBottomSheet({
    super.key,
    required this.videoId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  final LikeService _likeService = LikeService();
  List<ApiComment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  ApiComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      _commentService.getComments(widget.videoId).listen((comments) async {
        if (mounted) {
          setState(() {
            _comments = comments;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to comment')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      await _commentService.createComment(
        videoId: widget.videoId,
        text: text,
        parentCommentId: _replyingTo?.id,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus();
      _loadComments();
      // Clear reply state
      if (_replyingTo != null) {
        setState(() {
          _replyingTo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _toggleCommentLike(ApiComment comment) async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _likeService.toggleLike(
        userId: currentUserId,
        targetId: comment.id,
        targetType: 'Comment',
      );
      setState(() {

      });
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like comment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _replyToComment(ApiComment comment) {
    setState(() {
      _replyingTo = comment;
    });
    _commentController.text = '@${comment.user!.displayName} ';
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
    _commentController.clear();
  }

  int _totalCommentsWithReplies(List<ApiComment> comments) {
    int total = 0;

    for (var comment in comments) {
      total++;
      if (comment.replies != null && comment.replies!.isNotEmpty) {
        total += _totalCommentsWithReplies(comment.replies!);
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_totalCommentsWithReplies(_comments));
        return false;
      },
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_totalCommentsWithReplies(_comments)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Comments List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Be the first to comment!',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return _buildCommentItem(comment);
                            },
                          ),
              ),

              // Comment Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Reply indicator
                      if (_replyingTo != null)
                        Container(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Replying to comment',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _cancelReply,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Input field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isPosting
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: _addComment,
                                  icon: Icon(
                                    Icons.send,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(ApiComment comment,{bool isReply = false}) {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwner = currentUserId == comment.user?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: isReply ? 40 : 0,
            top: 8,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isReply)
                Container(
                  width: 2,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  height: 40,
                  color: Colors.grey[300],
                ),
              // Avatar
              CircleAvatar(
                radius: isReply ? 12 : 16,
                backgroundImage: (comment.user!.profileImageUrl ?? comment.user!.photoURL) != null
                    ? NetworkImage(comment.user!.profileImageUrl ?? comment.user!.photoURL!)
                    : null,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: (comment.user!.profileImageUrl == null && comment.user!.photoURL == null)
                    ? Icon(
                  Icons.person,
                  size: isReply ? 12 : 16,
                  color: Theme.of(context).colorScheme.primary,
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.user!.displayName ?? 'Unknown User',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isReply ? 12 : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(comment.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: isReply ? 10 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: isReply ? 13 : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleCommentLike(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.isLiked ? Icons.favorite : Icons.favorite_outline,
                                size: 14,
                                color: comment.isLiked ? Colors.red : Colors.grey[600],
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  comment.likesCount.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (!isReply)
                          GestureDetector(
                            onTap: () => _replyToComment(comment),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  switch (value) {
                    case 'delete':
                      _deleteComment(comment);
                      break;
                    case 'report':
                      _reportComment(comment);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (isOwner)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  if (!isOwner)
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Report Spam'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Render replies recursively
        if (comment.replies != null && comment.replies!.isNotEmpty)
          for (var reply in comment.replies!)
             _buildCommentItem(reply, isReply: true)
      ],
    );
  }

  Future<void> _deleteComment(ApiComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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
        await _commentService.deleteComment(comment.id, widget.videoId);
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reportComment(ApiComment comment) async {
    final reasons = {
      'Spam': 'spam',
      'Inappropriate content': 'inappropriate_content',
      'Harassment': 'harassment',
      'Other': 'other',
    };

    await showDialog(
      context: context,
      builder: (_) => ReportDialog(
        scaffoldContext: context,
        title: 'Report Comment',
        reasons: reasons,
        isDescriptionRequired: true,
        onSubmit: ({required reason, String? description}) async {
          return await handleReport(
            targetId: comment.id,
            targetType: 'Comment',
            reason: reason,
            description: description,
            onSuccess: () {
              if (mounted) _loadComments();
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
      return ''; // Keep dialog open
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
        // Call optional success callback
        onSuccess?.call();
      }

      return result;
    } catch (e) {
      Graphics.showToast(
        message: 'Failed to submit report: $e',
        isSuccess: false,
      );
      return ''; // Keep dialog open
    }
  }


}

typedef ReportSubmitCallback = Future<String> Function({
required String reason,
String? description,
});

class ReportDialog extends StatefulWidget {
  final String title;
  final Map<String, String> reasons;
  final bool isDescriptionRequired;
  final ReportSubmitCallback onSubmit;
  final BuildContext scaffoldContext;

  const ReportDialog({
    super.key,
    required this.title,
    required this.reasons,
    required this.onSubmit,
    this.isDescriptionRequired = false, required this.scaffoldContext,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? selectedReason;
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this?'),
              const SizedBox(height: 16),
              ...widget.reasons.keys.map(
                    (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() {
                    selectedReason = value;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: widget.isDescriptionRequired
                      ? 'Description (required)'
                      : 'Description (optional)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (selectedReason == null ||
              (widget.isDescriptionRequired &&
                  descriptionController.text.trim().isEmpty))
              ? null
              : () async {
            final reasonApi = widget.reasons[selectedReason!]!;
            final description = descriptionController.text.trim();

            try {
              final message = await widget.onSubmit(
                reason: reasonApi,
                description: description,
              );
              print('Report submitted: $message');
              // Close the dialog and return the message
              if (mounted) Navigator.pop(context, message);
            } catch (e) {
              // Close the dialog and return error message
              if (mounted) Navigator.pop(context, 'Failed to submit report: $e');
            }
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
