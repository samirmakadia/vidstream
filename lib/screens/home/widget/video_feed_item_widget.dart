import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vidstream/screens/home/widget/video_player_widget.dart';
import '../../../models/api_models.dart';
import '../../../repositories/api_repository.dart';
import '../../../services/socket_manager.dart';
import '../../../widgets/user_info_widget.dart';
import 'video_actions_widget.dart';

class VideoFeedItemWidget extends StatefulWidget {
  final ApiVideo video;
  final bool isActive;
  final void Function(ApiVideo video)? onVideoDeleted;
  final void Function(int likeCount, bool isLiked)? onLikeUpdated;
  final void Function(int commentCount)? onCommentUpdated;
  final void Function(ApiVideo video)? onReported;
  final void Function(ApiUser updatedUser)? onFollowUpdated;

  final ApiUser? user;
  final VoidCallback? onPauseRequested;
  final VoidCallback? onResumeRequested;

  const VideoFeedItemWidget({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoDeleted,
    this.onLikeUpdated, this.onCommentUpdated, this.onReported, this.onFollowUpdated, this.user, this.onPauseRequested, this.onResumeRequested,
  });

  @override
  State<VideoFeedItemWidget> createState() => _VideoFeedItemWidgetState();
}

class _VideoFeedItemWidgetState extends State<VideoFeedItemWidget> {
  bool _isLiked = false;
  bool _isLikeLoading = false;
  bool _isFollowLoading = false;
  int _localLikeCount = 0;
  final _videoKey = GlobalKey<VideoPlayerWidgetState>();

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.video.likesCount;
    _isLiked = widget.video.isLiked;
  }

  @override
  void didUpdateWidget(VideoFeedItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.likesCount != widget.video.likesCount) {
      _localLikeCount = widget.video.likesCount;
    }

    if (!widget.isActive && oldWidget.isActive) {
      _incrementViewCount();
    }
  }

  Future<void> _toggleLike() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null && !_isLikeLoading) {
      setState(() {
        _isLikeLoading = true;
      });

      try {
        await ApiRepository.instance.likes.toggleLike(
          userId: currentUserId,
          targetId: widget.video.id,
          targetType: 'Video',
        );
        setState(() {
          _isLiked = !_isLiked;
          if (_isLiked) {
            _localLikeCount++;
          } else {
            _localLikeCount = (_localLikeCount > 0) ? _localLikeCount - 1 : 0;
          }
        });
        eventBus.fire('like_updated');
        widget.onLikeUpdated?.call(_localLikeCount, _isLiked);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update like: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLikeLoading = false;
          });
        }
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null && currentUserId != widget.video.userId && !_isFollowLoading) {
      setState(() {
        _isFollowLoading = true;
      });

      try {
        await ApiRepository.instance.follows.toggleFollow(
          followerId: currentUserId,
          followedId: widget.video.userId,
        );
        if (widget.video.user != null) {
          final updatedUser = widget.video.user!.copyWith(
            followersCount: max(
              0,
              widget.video.user!.isFollow
                  ? widget.video.user!.followersCount - 1
                  : widget.video.user!.followersCount + 1,
            ),
            isFollow: !widget.video.user!.isFollow,
          );

          widget.onFollowUpdated?.call(updatedUser);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update follow: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isFollowLoading = false;
          });
        }
      }
    }
  }

  Future<void> _incrementViewCount() async {
    final betterController = _videoKey.currentState?.controller;
    if (betterController == null) return;

    final videoController = betterController.videoPlayerController;
    if (videoController == null) {
      // Retry if underlying controller is not ready
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _incrementViewCount();
      });
      return;
    }

    final videoValue = videoController.value;
    final totalDuration = videoValue.duration;
    final currentPosition = videoValue.position;

    if (totalDuration == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _incrementViewCount();
      });
      return;
    }

    final watchTime = currentPosition.inSeconds;
    final watchPercentage = totalDuration.inSeconds > 0
        ? (watchTime / totalDuration.inSeconds) * 100
        : 0.0;

    await ApiRepository.instance.videos.incrementViewCount(
      widget.video.id,
      watchTime: watchTime,
      watchPercentage: watchPercentage.round().toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerWidget(
          key: _videoKey,
          videoUrl: widget.video.videoUrl,
          isActive: widget.isActive,
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 230,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Video Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info
                      if (widget.video.user != null)
                        UserInfoWidget(
                          user: widget.video.user!,
                        ),

                      const SizedBox(height: 2),

                      // Video Description
                      if (widget.video.description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric( vertical: 4),
                          child: Text(
                            widget.video.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 6),

                      // Tags
                      if (widget.video.tags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: widget.video.tags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Video Actions
                VideoActionsWidget(
                  isFollowLoading: _isFollowLoading,
                  onFollowToggle: _toggleFollow,
                  user: widget.video.user!,
                  video: widget.video,
                  isLiked: _isLiked,
                  onLikeToggle: _toggleLike,
                  likeCount: _localLikeCount,
                  isLikeLoading: _isLikeLoading,
                  onVideoDeleted: widget.onVideoDeleted,
                  onCommentUpdated: (newCount) {
                    setState(() {
                      widget.onCommentUpdated?.call(newCount);
                    });
                  },
                  onReported: (reportedVideo) {
                    setState(() {
                      widget.onReported?.call(reportedVideo);
                    });
                  },
                  onPauseRequested: () => widget.onPauseRequested?.call(),
                  onResumeRequested: () => widget.onResumeRequested?.call(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}