import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:vidmeet/screens/home/bottomsheet/report_dialog.dart';
import '../../../helper/navigation_helper.dart';
import '../../../manager/applovin_ad_manager.dart';
import '../../../manager/setting_manager.dart';
import '../../../models/api_models.dart';
import '../../../repositories/api_repository.dart';
import '../../../services/comment_service.dart';
import '../../../services/like_service.dart';
import '../../../utils/graphics.dart';
import '../../../widgets/custom_image_widget.dart';
import '../../../widgets/empty_section.dart';
import '../../other_user_profile_screen.dart';

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
  Set<String> _loadingCommentLikes = {};
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          _hasMore) {
        _loadComments();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refreshComments() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _isFetchingMore = false;
      _isLoading = false;
    });
    await _loadComments(reset: true);
  }

  Future<void> _loadComments({bool reset = false}) async {
    if (_isFetchingMore || (!_hasMore && !reset)) return;

    if(!reset) {
      setState(() => _isFetchingMore = true);
    }

    try {
      final pageToFetch = reset ? 1 : _currentPage;
      _commentService
          .getComments(widget.videoId, limit: _pageSize, page: pageToFetch)
          .listen((comments) {
        if (!mounted) return;
        setState(() {
          if (pageToFetch == 1) {
            _comments = comments;
          } else {
            _comments.addAll(comments);
          }

          _hasMore = comments.length == _pageSize;
          _isFetchingMore = false;
          _isLoading = false;
          _currentPage = pageToFetch + 1;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingMore = false;
        _isLoading = false;
      });
      Graphics.showTopDialog(
        context,
        "Error!",
        'Failed to load comments: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) {
      Graphics.showTopDialog(
        context,
        "Error!",
        'Please login to comment',
        type: ToastType.error,
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
      _refreshComments();
      // Clear reply state
      if (_replyingTo != null) {
        setState(() {
          _replyingTo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        Graphics.showTopDialog(
          context,
          "Error!",
          'Failed to post comment: $e',
          type: ToastType.error,
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

    setState(() {
      _loadingCommentLikes.add(comment.id);
    });

    try {
      await _likeService.toggleLike(
        userId: currentUserId,
        targetId: comment.id,
        targetType: 'Comment',
      );
      setState(() {
        comment.isLiked = !comment.isLiked;
        comment.likesCount += comment.isLiked ? 1 : -1;
      });
      _refreshComments();
    } catch (e) {
      if (mounted) {
        Graphics.showTopDialog(
          context,
          "Error!",
          'Failed to like comment: $e',
          type: ToastType.error,
        );
      }
    }finally {
      setState(() {
        _loadingCommentLikes.remove(comment.id);
      });
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

  void _navigateToUserProfile(ApiUser user) {
    NavigationHelper.navigateWithAd(
      context: context,
      destination: OtherUserProfileScreen(
        userId: user.id,
        displayName: user.displayName,
      ),
    );
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
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Divider(height: 1, color: Colors.grey.withOpacity(0.5)),
              SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? Center(
                  child: EmptySection(
                    icon: Icons.comment_outlined,
                    title: 'No comments yet',
                    subtitle: 'Be the first to comment!',
                  ),
                )
                    : _buildCommentList()
              ),
              _buildCommentInput(),
            ],
          ),
        ),
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
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
        ]
    );
  }

  Widget _buildCommentList() {
    int adInterval = SettingManager().nativeFrequency;
    final showEndAd = _comments.length < adInterval && AppLovinAdManager.isMrecAdLoaded;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _comments.length +
          (_comments.length >= adInterval ? (_comments.length / adInterval).ceil() : 0) +
          (showEndAd ? 1 : 0) +
          (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {

        if (_isFetchingMore && index == _comments.length + (_comments.length >= adInterval ? (_comments.length / adInterval).ceil() : 0) + (showEndAd ? 1 : 0) - 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (_comments.length >= adInterval && (index + 1) % (adInterval + 1) == 0) {
          return AppLovinAdManager.isMrecAdLoaded
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AppLovinAdManager.mrecAd(),
          )
              : const SizedBox.shrink();
        }

        if (showEndAd && index == _comments.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AppLovinAdManager.mrecAd(),
          );
        }

        final commentIndex = index - (index ~/ (adInterval + 1));
        if (commentIndex >= _comments.length) return const SizedBox.shrink();

        final comment = _comments[commentIndex];
        return _buildCommentItem(comment);
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.5)),
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
                      fillColor: Colors.grey.withOpacity(0.1),
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
              GestureDetector(
                onTap: () => _navigateToUserProfile(comment.user!),
                child: Container(
                  height: isReply ? 24 : 32, // diameter = 2 * radius
                  width: isReply ? 24 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: (comment.user?.profileImageUrl?.isNotEmpty == true ||
                      comment.user?.photoURL?.isNotEmpty == true)
                      ? ClipOval(
                    child: CustomImageWidget(
                      imageUrl: comment.user!.profileImageUrl ??
                          comment.user!.photoURL ??
                          '',
                      height: isReply ? 24 : 32,
                      width: isReply ? 24 : 32,
                      cornerRadius: (isReply ? 12 : 16),
                      borderWidth: 0,
                      fit: BoxFit.cover,
                    ),
                  )
                      : CircleAvatar(
                    radius: isReply ? 12 : 16,
                    backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: isReply ? 12 : 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _navigateToUserProfile(comment.user!),
                            child: Text(
                              comment.user!.displayName ?? 'Unknown User',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: isReply ? 12 : null,
                              ),
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(comment.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: isReply ? 10 : null,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                          onTap: _loadingCommentLikes.contains(comment.id)
                              ? null
                              : () => _toggleCommentLike(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_loadingCommentLikes.contains(comment.id))
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  comment.isLiked ? Icons.favorite : Icons.favorite_outline,
                                  size: 14,
                                  color: comment.isLiked ? Colors.red : Colors.grey[600],
                                ),
                              if (comment.likesCount > 0 && !_loadingCommentLikes.contains(comment.id)) ...[
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
                padding: EdgeInsets.zero,
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
      FocusManager.instance.primaryFocus?.unfocus();
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
        FocusManager.instance.primaryFocus?.unfocus();
        try {
          await _commentService.deleteComment(comment.id, widget.videoId);
          _refreshComments();
          if (mounted) {
            Graphics.showTopDialog(
              context,
              "Success!",
              'Comment deleted successfully',
            );
          }
        } catch (e) {
          if (mounted) {
            Graphics.showTopDialog(
              context,
              "Error!",
              'Failed to delete comment: $e',
              type: ToastType.error,
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
      'Fake Account': 'fake_account',
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
              if (mounted) _refreshComments();
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
      Graphics.showTopDialog(
        context,
        "Error",
        'Failed to submit report: $e',
        type: ToastType.error,
      );
      return '';
    }
  }


}