import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:flutter/services.dart';
import 'package:vidstream/services/comment_service.dart';
import 'package:vidstream/services/like_service.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class VideoActionsWidget extends StatefulWidget {
  final ApiVideo video;
  final bool isLiked;
  final VoidCallback onLikeToggle;
  final bool isLikeLoading;
  final VoidCallback? onVideoDeleted;
  final int likeCount;
  final void Function(int commentCount)? onCommentUpdated;

  const VideoActionsWidget({
    super.key,
    required this.video,
    required this.isLiked,
    required this.onLikeToggle,
    this.isLikeLoading = false,
    this.onVideoDeleted, required this.likeCount,
    this.onCommentUpdated,
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
    // Copy video link to clipboard
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
                  _reportVideo(context);
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

  Future<void> _reportVideo(BuildContext context) async {
    final reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment',
      'Violence',
      'Copyright violation',
      'Other',
    ];

    String? selectedReason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Report Video', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you reporting this video?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(color: Colors.white)),
              value: reason,
              groupValue: null,
              onChanged: (value) => Navigator.pop(context, value),
              activeColor: Theme.of(context).colorScheme.primary,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedReason != null) {
      try {
        final currentUserId = ApiRepository.instance.auth.currentUser?.id;
        if (currentUserId != null) {
          await ApiRepository.instance.reports.reportContent(
            reporterId: currentUserId,
            targetId: widget.video.id,
            targetType: 'video',
            reason: selectedReason,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
  ApiComment? _replyingTo; // Track which comment we're replying to
  final Map<String, bool> _commentLikes = {}; // Cache comment like states

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    Navigator.of(context).pop(_comments.length);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      _commentService.getComments(widget.videoId).listen((comments) async {
        if (mounted) {
          // Load like states for all comments
          await _loadCommentLikeStates(comments);
          
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

  Future<void> _loadCommentLikeStates(List<ApiComment> comments) async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      for (final comment in comments) {
        final isLiked = await _likeService.hasUserLiked(
          userId: currentUserId,
          targetId: comment.id,
          targetType: 'Comment',
        );
        _commentLikes[comment.id] = isLiked;
      }
    } catch (e) {
      print('Failed to load comment like states: $e');
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
      
      // Update local cache
      final isLiked = _commentLikes[comment.id] ?? false;
      setState(() {
        _commentLikes[comment.id] = !isLiked;
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_comments.length);
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
                      onPressed: () => Navigator.of(context).pop(_comments.length),
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
                              return FutureBuilder<ApiUser?>(
                                future: ApiRepository.instance.auth.getUserProfile(comment.user!.id),
                                builder: (context, snapshot) {
                                  final user = snapshot.data;
                                  return _buildCommentItem(comment, user);
                                },
                              );
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

  Widget _buildCommentItem(ApiComment comment, ApiUser? user) {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwner = currentUserId == comment.user!.id;
    final isReply = comment.parentCommentId != null;
    final isLiked = _commentLikes[comment.id] ?? false;
    
    return Container(
      margin: EdgeInsets.fromLTRB(
        isReply ? 48 : 0, // Indent replies
        8,
        0,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply indicator line for replies
          if (isReply)
            Container(
              width: 2,
              height: 24,
              color: Colors.grey[300],
              margin: const EdgeInsets.only(right: 12, top: 8),
            ),
          CircleAvatar(
            radius: isReply ? 12 : 16, // Smaller avatar for replies
            backgroundImage: user?.profileImageUrl != null || user?.photoURL != null
                ? NetworkImage(user!.profileImageUrl ?? user!.photoURL!)
                : null,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: (user?.profileImageUrl == null && user?.photoURL == null)
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
                      user?.displayName ?? 'Unknown User',
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
                const SizedBox(height: 8),
                // Like and Reply buttons
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: () => _toggleCommentLike(comment),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_outline,
                            size: 14,
                            color: isLiked ? Colors.red : Colors.grey[600],
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
                    // Reply button (only for parent comments)
                    if (!isReply)
                      GestureDetector(
                        onTap: () => _replyToComment(comment),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
    final reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment',
      'Other',
    ];

    String? selectedReason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Comment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this comment?'),
            const SizedBox(height: 16),
            ...reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: null,
              onChanged: (value) => Navigator.pop(context, value),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedReason != null) {
      try {
        final currentUserId = ApiRepository.instance.auth.currentUser?.id;
        if (currentUserId != null) {
          await ApiRepository.instance.reports.reportContent(
            reporterId: currentUserId,
            targetId: comment.id,
            targetType: 'comment',
            reason: selectedReason,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}