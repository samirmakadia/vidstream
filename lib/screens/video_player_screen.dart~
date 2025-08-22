import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/widgets/video_player_widget.dart';
import 'package:vidstream/widgets/video_actions_widget.dart';
import 'package:vidstream/widgets/user_info_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final ApiVideo video;
  final List<ApiVideo> allVideos;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.allVideos,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageController;
  late List<ApiVideo> _videos;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.allVideos);
    
    // Find the initial video index
    final initialIndex = _videos.indexWhere((v) => v.id == widget.video.id);
    _currentIndex = initialIndex != -1 ? initialIndex : 0;
    
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoFeedItem(
                video: video,
                isActive: index == _currentIndex,
                onVideoDeleted: () {
                  setState(() {
                    _videos.removeAt(index);
                    if (_videos.isEmpty) {
                      Navigator.of(context).pop();
                    } else if (index <= _currentIndex && _currentIndex > 0) {
                      _currentIndex--;
                    }
                  });
                },
              );
            },
          ),
          
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoFeedItem extends StatefulWidget {
  final ApiVideo video;
  final bool isActive;
  final VoidCallback? onVideoDeleted;

  const VideoFeedItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoDeleted,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  ApiUser? _user;
  bool _isLiked = false;
  bool _isFollowing = false;
  bool _isLikeLoading = false;
  bool _isFollowLoading = false;
  int _localLikeCount = 0;
  int _localViewCount = 0;
  bool _hasIncrementedView = false;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.video.likesCount;
    _localViewCount = widget.video.viewsCount;
    _loadUserData();
    _checkLikeStatus();
    _checkFollowStatus();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If video becomes active and we haven't incremented view yet
    if (widget.isActive && !oldWidget.isActive && !_hasIncrementedView) {
      _incrementViewCount();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await ApiRepository.instance.auth.getUserProfile(widget.video.userId);
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _checkLikeStatus() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final isLiked = await ApiRepository.instance.likes.hasUserLiked(
          userId: currentUserId,
          targetId: widget.video.id,
          targetType: 'video',
        );
        if (mounted) {
          setState(() {
            _isLiked = isLiked;
          });
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null && currentUserId != widget.video.userId) {
      try {
        final isFollowing = await ApiRepository.instance.follows.isFollowing(
          followerId: currentUserId,
          followedId: widget.video.userId,
        );
        if (mounted) {
          setState(() {
            _isFollowing = isFollowing;
          });
        }
      } catch (e) {
        // Handle error silently
      }
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
          targetType: 'video',
        );
        setState(() {
          _isLiked = !_isLiked;
          // Update like count locally for immediate UI feedback
          if (_isLiked) {
            _localLikeCount++;
          } else {
            _localLikeCount = (_localLikeCount > 0) ? _localLikeCount - 1 : 0;
          }
          print('Like status toggled. New like count: $_localLikeCount');
        });
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
        setState(() {
          _isFollowing = !_isFollowing;
          // Update user follower count locally for immediate UI feedback
          if (_user != null) {
            if (_isFollowing) {
              _user!.followers.add(currentUserId);
            } else {
              _user!.followers.remove(currentUserId);
            }
          }
        });
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
    if (_hasIncrementedView) return;
    
    try {
      // Immediately update local view count for UI feedback
      setState(() {
        _localViewCount++;
        _hasIncrementedView = true;
      });
      
      // Update view count in Firebase
      await ApiRepository.instance.videos.incrementViewCount(widget.video.id);
    } catch (e) {
      // Silently handle error - view count increment is not critical
      print('Failed to increment view count: $e');
      // Revert local count on error
      if (mounted) {
        setState(() {
          _localViewCount = widget.video.viewsCount;
          _hasIncrementedView = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        VideoPlayerWidget(
          videoUrl: widget.video.videoUrl,
          isActive: widget.isActive,
        ),
        
        // Video Info and Actions Overlay
        Positioned(
          bottom: 100,
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
                      if (_user != null)
                        UserInfoWidget(
                          user: _user!,
                          isFollowing: _isFollowing,
                          onFollowToggle: _toggleFollow,
                          showFollowButton: ApiRepository.instance.auth.currentUser?.uid != widget.video.userId,
                          isFollowLoading: _isFollowLoading,
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Video Description
                      if (widget.video.description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.video.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
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
                  video: widget.video.copyWith(
                    likesCount: _localLikeCount,
                    viewsCount: _localViewCount,
                  ),
                  isLiked: _isLiked,
                  onLikeToggle: _toggleLike,
                  likeCount: _localLikeCount,
                  isLikeLoading: _isLikeLoading,
                  onVideoDeleted: widget.onVideoDeleted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}