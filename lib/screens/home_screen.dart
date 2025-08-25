import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/widgets/video_player_widget.dart';
import 'package:vidstream/widgets/video_actions_widget.dart';
import 'package:vidstream/widgets/user_info_widget.dart';
import 'package:vidstream/screens/search_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<ApiVideo> _videos = [];
  List<ApiVideo> _allVideos = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isSearching = false;
  List<String> _selectedTags = [];
  Timer? _searchDebounce;
  bool _isScreenVisible = true;
  
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  
  // Common video tags for filtering
  final List<String> _availableTags = [
    'funny', 'comedy', 'emotional', 'music', 'dance', 'sports',
    'food', 'travel', 'lifestyle', 'tutorial', 'gaming', 'pets',
    'beauty', 'fashion', 'art', 'nature', 'fitness', 'education'
  ];

  @override
  bool get wantKeepAlive => true;

  // Public method to control screen visibility from parent
  void setScreenVisible(bool isVisible) {
    if (mounted && _isScreenVisible != isVisible) {
      setState(() {
        _isScreenVisible = isVisible;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchAnimationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is going to background or being inactive
        setState(() {
          _isScreenVisible = false;
        });
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        setState(() {
          _isScreenVisible = true;
        });
        break;
    }
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videos = await ApiRepository.instance.videos.getVideosOnce();
      setState(() {
        _videos = videos;
        _allVideos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load videos: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  Future<void> _refreshVideos() async {
    await _loadVideos();
  }
  
  void _openSearchScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }
  
  void _performSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty && _selectedTags.isEmpty) {
        _clearSearch();
        return;
      }
      
      setState(() {
        _isSearching = true;
      });
      
      List<ApiVideo> filteredVideos = _allVideos.where((video) {
        bool matchesQuery = query.isEmpty || 
            video.title.toLowerCase().contains(query.toLowerCase()) ||
            video.description.toLowerCase().contains(query.toLowerCase()) ||
            video.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
        
        bool matchesTags = _selectedTags.isEmpty ||
            _selectedTags.any((selectedTag) => 
                video.tags.any((videoTag) => 
                    videoTag.toLowerCase() == selectedTag.toLowerCase()));
        
        return matchesQuery && matchesTags;
      }).toList();
      
      setState(() {
        _videos = filteredVideos;
        _isSearching = false;
        _currentIndex = 0;
      });
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  void _clearSearch() {
    setState(() {
      _videos = _allVideos;
      _selectedTags.clear();
      _isSearching = false;
      _currentIndex = 0;
    });
    
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _showFilterDialog() {
    // Create a copy of selected tags for the bottom sheet
    List<String> tempSelectedTags = List.from(_selectedTags);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Videos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (tempSelectedTags.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${tempSelectedTags.length} selected',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select tags to filter your video feed',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Tags grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _availableTags.length,
                        itemBuilder: (context, index) {
                          final tag = _availableTags[index];
                          final isSelected = tempSelectedTags.contains(tag);
                          
                          return GestureDetector(
                            onTap: () {
                              setBottomSheetState(() {
                                if (isSelected) {
                                  tempSelectedTags.remove(tag);
                                } else {
                                  tempSelectedTags.add(tag);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      if (tempSelectedTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Active Filters',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tempSelectedTags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 10), // Extra space for buttons
                    ],
                  ),
                ),
              ),
              
              // Bottom actions
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color(0xFF262626),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Clear button
                      if (tempSelectedTags.isNotEmpty)
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () {
                              setBottomSheetState(() {
                                tempSelectedTags.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white.withValues(alpha: 0.8),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      
                      if (tempSelectedTags.isNotEmpty) const SizedBox(width: 12),
                      
                      // Apply button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTags = List.from(tempSelectedTags);
                            });
                            Navigator.pop(context);
                            _performSearch(_searchController.text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(
                            tempSelectedTags.isEmpty 
                                ? 'Show All Videos' 
                                : 'Apply Filters (${tempSelectedTags.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  void _updateLikeCount(String videoId, int newCount) {
    final i = _videos.indexWhere((v) => v.id == videoId);
    if (i != -1) {
      _videos[i] = _videos[i].copyWith(likesCount: newCount);
    }
    final j = _allVideos.indexWhere((v) => v.id == videoId);
    if (j != -1) {
      _allVideos[j] = _allVideos[j].copyWith(likesCount: newCount);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _videos.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refreshVideos,
                      child: PageView.builder(
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
                            key: ValueKey(video.id),
                            video: video,
                            isActive: index == _currentIndex && _isScreenVisible,
                            onVideoDeleted: () {
                              setState(() {
                                _videos.removeAt(index);
                                _allVideos.removeWhere((v) => v.id == video.id);
                              });
                            },
                            onLikeUpdated: (newCount, isLiked) {
                              _updateLikeCount(video.id, newCount);
                            },
                            onCommentUpdated: (newCount) {
                              setState(() {
                                final i = _videos.indexWhere((v) => v.id == video.id);
                                if (i != -1) _videos[i] = _videos[i].copyWith(commentsCount: newCount);
                                final j = _allVideos.indexWhere((v) => v.id == video.id);
                                if (j != -1) _allVideos[j] = _allVideos[j].copyWith(commentsCount: newCount);
                              });
                            },
                            onReported: (reportedVideo) {
                              setState(() {
                                _videos.removeWhere((v) => v.id == reportedVideo.id);
                              });
                            },
                            onFollowUpdated: (updatedUser) {
                              setState(() {
                                final i = _videos.indexWhere((v) => v.id == video.id);
                                if (i != -1) _videos[i] = _videos[i].copyWith(user: updatedUser);
                                final j = _allVideos.indexWhere((v) => v.id == video.id);
                                if (j != -1) _allVideos[j] = _allVideos[j].copyWith(user: updatedUser);
                              });
                            },
                          );
                        },
                      ),
                    ),
          
          // Top action bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildTopActionBar(),
          ),
          
          // Loading overlay
          if (_isSearching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar() {
    // Normal mode - show search and filter icons
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Search icon
        GestureDetector(
          onTap: _openSearchScreen,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.search,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        
        // Filter icon
        GestureDetector(
          onTap: _showFilterDialog,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedTags.isNotEmpty 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.filter_list,
                  color: _selectedTags.isNotEmpty 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.white,
                  size: 18,
                ),
                if (_selectedTags.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_selectedTags.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isNotEmpty || _selectedTags.isNotEmpty
                ? Icons.search_off
                : Icons.video_library_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty || _selectedTags.isNotEmpty
                ? 'No videos found'
                : 'No videos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedTags.isNotEmpty
                ? 'Try different keywords or filters'
                : 'Be the first to share a video!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          if (_searchController.text.isNotEmpty || _selectedTags.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _clearSearch();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _refreshVideos,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
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
  final void Function(int likeCount, bool isLiked)? onLikeUpdated;
  final void Function(int commentCount)? onCommentUpdated;
  final void Function(ApiVideo video)? onReported;
  final void Function(ApiUser updatedUser)? onFollowUpdated;

  const VideoFeedItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoDeleted,
    this.onLikeUpdated, this.onCommentUpdated, this.onReported, this.onFollowUpdated,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  bool _isLiked = false;
  bool _isLikeLoading = false;
  bool _isFollowLoading = false;
  int _localLikeCount = 0;
  final _videoKey = GlobalKey<VideoPlayerWidgetState>();

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.video.likesCount;
     _checkLikeStatus();
   }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.likesCount != widget.video.likesCount) {
      _localLikeCount = widget.video.likesCount;
    }

    if (!widget.isActive && oldWidget.isActive) {
      _incrementViewCount();
    }
  }


  Future<void> _checkLikeStatus() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final isLiked = await ApiRepository.instance.likes.hasUserLiked(
          userId: currentUserId,
          targetId: widget.video.id,
          targetType: 'Video',
        );
        if (mounted) {
          setState(() {
            _isLiked = isLiked;
          });
        }
      } catch (e) {
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
    final videoController = _videoKey.currentState?.controller;
    if (videoController == null) {
      return;
    }
    if (!videoController.value.isInitialized) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _incrementViewCount();
      });
      return;
    }

    final currentPosition = videoController.value.position;
    final totalDuration = videoController.value.duration;

    final watchTime = currentPosition.inSeconds;
    final watchPercentage = totalDuration.inSeconds > 0 ? (watchTime / totalDuration.inSeconds) * 100 : 0.0;

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
                          onFollowToggle: _toggleFollow,
                          showFollowButton: ApiRepository.instance.auth.currentUser?.id != widget.video.userId,
                          isFollowLoading: _isFollowLoading,
                        ),
                      
                      const SizedBox(height: 2),
                      
                      // Video Description
                      if (widget.video.description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric( vertical: 4),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}