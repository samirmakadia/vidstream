import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/services/follow_service.dart';
import 'package:vidstream/services/block_service.dart';
import 'package:vidstream/screens/follower_following_list_screen.dart';
import 'package:vidstream/screens/video_player_screen.dart';

import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../services/socket_manager.dart';
import '../utils/utils.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/image_preview_screen.dart';
import '../widgets/professional_bottom_ad.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  final String? displayName;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    this.displayName,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with TickerProviderStateMixin {
  ApiUser? _user;
  List<ApiVideo> _userVideos = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isBlocked = false;
  bool _isBlockLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  final FollowService _followService = FollowService();
  final BlockService _blockService = BlockService();
  double offsetY = 0;
  late StreamSubscription _videoUploadedSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _initAnimations();
    _loadUserProfile();
    _videoUploadedSubscription = eventBus.on().listen((event) {
     if (event == 'updatedUser') {
        _loadUserProfile(isLoadingShow: false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }

  Future<void> _loadUserProfile({bool isLoadingShow = true}) async {
    try {
      if(isLoadingShow) {
        setState(() => _isLoading = true);
      }

      // Load user profile
      final user =
          await ApiRepository.instance.auth.getUserProfile(widget.userId);

      // Load user's videos
      List<ApiVideo> videos = [];
      try {
        videos =
            await ApiRepository.instance.videos.getUserPostedVideos(widget.userId);
      } catch (e) {
        print('Failed to load user videos: $e');
      }

      // Get follow counts
      try {
        final followerCount = await ApiRepository.instance.follows
            .getFollowerCount(widget.userId);
        final followingCount = await ApiRepository.instance.follows
            .getFollowingCount(widget.userId);

        _followerCount = followerCount;
        _followingCount = followingCount;
      } catch (e) {
        print('Failed to load follow counts: $e');
      }

      // Check if current user is following this user and block status
      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null && currentUserId != widget.userId) {
        try {
          _isFollowing = await _followService.isFollowing(
            followerId: currentUserId,
            followedId: widget.userId,
          );

          _isBlocked = await _blockService.isUserBlocked(
            checkerId: currentUserId,
            checkedId: widget.userId,
          );
        } catch (e) {
          print('Failed to check follow/block status: $e');
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _userVideos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadUserProfile,
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId || _isBlocked) {
      return;
    }
    setState(() => _isFollowLoading = true);

    try {
      await _followService.toggleFollow(
        followerId: currentUserId,
        followedId: widget.userId,
      );

      // Update UI state
      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followerCount++;
        } else {
          _followerCount--;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing
              ? 'Following ${_user?.displayName}'
              : 'Unfollowed ${_user?.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
      eventBus.fire('updatedUser');
      eventBus.fire({
        "userId": widget.userId,
        "isFollow": _isFollowing,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _toggleBlock() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) return;

    setState(() => _isBlockLoading = true);
    await Utils.showLoaderWhile(context, () async {
      try {
        if (_isBlocked) {
          await _blockService.unblockUser(
            blockerId: currentUserId,
            blockedId: widget.userId,
          );
        } else {
          await _blockService.blockUser(
            blockerId: currentUserId,
            blockedId: widget.userId,
          );
        }

        setState(() {
          _isBlocked = !_isBlocked;
          if (_isBlocked) {
            if (_isFollowing) {
              _isFollowing = false;
              // _followerCount--;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked
                ? 'Blocked ${_user?.displayName}'
                : 'Unblocked ${_user?.displayName}'),
            backgroundColor: _isBlocked ? Colors.red : Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isBlocked ? 'unblock' : 'block'}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        setState(() => _isBlockLoading = false);
      }
    });
  }

  void _showBlockConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            _isBlocked ? 'Unblock User' : 'Block User',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _isBlocked
                ? 'Are you sure you want to unblock ${_user?.displayName}? They will be able to see your profile and interact with your content again.'
                : 'Are you sure you want to block ${_user?.displayName}? They won\'t be able to see your profile or interact with your content. This will also unfollow both of you.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _toggleBlock();
              },
              child: Text(
                _isBlocked ? 'Unblock' : 'Block',
                style: TextStyle(color: _isBlocked ? Colors.green : Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToFollowersList(int initialTabIndex) {
    if (_user == null) return;
    NavigationHelper.navigateWithAd(
      context: context,
      destination: FollowerFollowingListScreen(
        userId: _user!.id,
        initialTabIndex: initialTabIndex,
        displayName: _user!.displayName,
      ),
      onReturn: (_) {
        print("Returned from follower/following screen");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.displayName ?? 'Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(true);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            setState(() {
              offsetY = scrollInfo.metrics.pixels;
            });
            return true;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ProfessionalBottomAd(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: RefreshIndicator(
                      onRefresh: _loadUserProfile,
                      child: CustomScrollView(
                        slivers: [
                          _buildSliverAppBar(isOwnProfile),
                          _buildProfileInfo(isOwnProfile),
                          _buildStatsSection(),
                          _buildTabBar(),
                          _buildTabContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 300 - offsetY - 70,
                left: MediaQuery.of(context).size.width / 2 - 100 / 2,
                child: _buildFloatingAvatar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAvatar() {
    return GestureDetector(
      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewScreen(
              imageUrl: _user?.profileImageUrl ?? _user?.photoURL,
              isAvatar: true,
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: (_user?.profileImageUrl != null && _user!.profileImageUrl!.isNotEmpty) ||
            (_user?.photoURL != null && _user!.photoURL!.isNotEmpty)
            ? ClipOval(
          child: CustomImageWidget(
            imageUrl: _user?.profileImageUrl?.isNotEmpty == true
                ? _user!.profileImageUrl!
                : _user!.photoURL!,
            height: double.infinity,
            width: double.infinity,
            cornerRadius: 0,
            borderWidth: 0,
            fit: BoxFit.cover,
          ),
        )
            : CircleAvatar(
          radius: 46,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(
            Icons.person,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isOwnProfile) {
    return SliverAppBar(
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(_user?.displayName ?? 'Profile'),
      actions: [
        if (!isOwnProfile)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (String value) {
              switch (value) {
                case 'block':
                  _showBlockConfirmationDialog();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'block',
                child: ListTile(
                  leading: Icon(
                    _isBlocked ? Icons.person_add : Icons.block,
                    color: _isBlocked ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    _isBlocked ? 'Unblock User' : 'Block User',
                    style: TextStyle(
                      color: _isBlocked ? Colors.green : Colors.red,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final banner = _user?.bannerImageUrl;
            if (banner != null && banner.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImagePreviewScreen(
                    imageUrl: banner,
                    isAvatar: false,
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner Image
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Color(0xFFA3E635),
                      Color(0xFF2E7D32),
                    ],
                  ),
                ),
                child: _user?.bannerImageUrl != null && _user!.bannerImageUrl!.isNotEmpty
                    ? CustomImageWidget(
                  imageUrl: _user!.bannerImageUrl!,
                  height: double.infinity,
                  width: double.infinity,
                  cornerRadius: 0,
                  borderWidth: 0,
                  fit: BoxFit.cover,
                )
                    : null,
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
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

  Widget _buildProfileInfo(bool isOwnProfile) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 40,),
            Text(
              _user?.displayName ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_user?.bio != null) ...[
              Text(
                _user!.bio ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (_user?.isGuest == true)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  '👤 Guest User',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            if (!isOwnProfile) ...[
              const SizedBox(height: 16),
              if (_isBlocked) ...[
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Blocked',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isFollowLoading ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing
                          ? Colors.white.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: _isFollowing
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: 0.3))
                            : BorderSide.none,
                      ),
                    ),
                    child: _isFollowLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFollowing
                                    ? Icons.person_remove
                                    : Icons.person_add,
                                size: 20,
                                color: _isFollowing ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _isFollowing ? Colors.white :Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem('Videos', _userVideos.length.toString(),
                  onTap: null),
            ),
            Expanded(
              child: _buildStatItem('Followers', _followerCount.toString(),
                  onTap: () => _navigateToFollowersList(0)),
            ),
            Expanded(
              child: _buildStatItem('Following', _followingCount.toString(),
                  onTap: () => _navigateToFollowersList(1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, {VoidCallback? onTap}) {
    final child = Column(
      children: [
        Text(
          count,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 10),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Posts (${_userVideos.length})'),
                ],
              ),
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          indicator: const BoxDecoration(),
          dividerColor: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final videos = _userVideos;

    if (videos.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 250,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'No videos yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_user?.displayName ?? 'This user'} hasn\'t posted any videos yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    const int videosPerRow = 3;
    const int rowsBeforeAd = 2;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> children = [];

    for (int i = 0; i < videos.length; i += videosPerChunk) {
      final end = (i + videosPerChunk < videos.length) ? i + videosPerChunk : videos.length;
      final videosChunk = videos.sublist(i, end);

      children.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videosChunk.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: videosPerRow,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.7,
          ),
          itemBuilder: (context, index) {
            final video = videosChunk[index];
            return _buildVideoGridItem(video);
          },
        ),
      );

      children.add(const SizedBox(height: 8));
      if (AppLovinAdManager.isNativeAdLoaded) {
        children.add(AppLovinAdManager.nativeAdSmall(height: 110));
        children.add(const SizedBox(height: 8));
      }
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }


  Widget _buildVideoGridItem(ApiVideo video) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openVideoPlayer(video),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[900],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: video.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 32,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.video_library,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 32,
                        ),
                      ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              // Video stats
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            video.likesCount.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 12,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            video.viewsCount.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
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

  Future<void> _openVideoPlayer(ApiVideo video) async {
    NavigationHelper.navigateWithAd(
      context: context,
      destination: VideoPlayerScreen(
        video: video,
        allVideos: _userVideos,
        user: _user,
      ),
      onReturn: (result) {
        if (result != null) {
          _loadUserProfile(isLoadingShow: false);
        }
      },
    );
  }
}
