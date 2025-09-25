import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/services/follow_service.dart';
import 'package:vidmeet/services/block_service.dart';
import 'package:vidmeet/screens/follower_following_list_screen.dart';
import 'package:vidmeet/screens/video_player_screen.dart';
import '../helper/navigation_helper.dart';
import '../manager/applovin_ad_manager.dart';
import '../manager/setting_manager.dart';
import '../services/socket_manager.dart';
import '../utils/graphics.dart';
import '../utils/utils.dart';
import 'ads/banner_ad_widget.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/empty_section.dart';
import '../widgets/image_preview_screen.dart';
import '../widgets/video_grid_item_widget.dart';

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

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> with TickerProviderStateMixin {
  ApiUser? _user;
  List<ApiVideo> _userVideos = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isBlocked = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _followerCount = 0;
  int _followingCount = 0;
  final FollowService _followService = FollowService();
  final BlockService _blockService = BlockService();
  double offsetY = 0;
  late StreamSubscription _videoUploadedSubscription;
  int _currentPage = 1;
  bool _isFetchingMore = false;
  bool _hasMoreVideos = true;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserProfile();
    _videoUploadedSubscription = eventBus.on().listen((event) {
      if (event is Map<String, dynamic>) {
        final type = event['type'];
        if (type == 'updatedVideo') {
          _loadPostVideos(reset: true);
        }
      }
      if (event == 'updatedUser') {
        _loadUserProfile(isLoadingShow: false);
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          _hasMoreVideos) {
        _loadPostVideos();
      }
    });
  }

  @override
  void dispose() {
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
      final user = await ApiRepository.instance.auth.getUserProfile(widget.userId);
      await _loadPostVideos(reset: true);
      try {
        final followerCount = await ApiRepository.instance.follows.getFollowerCount(widget.userId);
        final followingCount = await ApiRepository.instance.follows.getFollowingCount(widget.userId);
        _followerCount = followerCount;
        _followingCount = followingCount;
      } catch (e) {
        print('Failed to load follow counts: $e');
      }

      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null && currentUserId != widget.userId) {
        try {
          _isFollowing = await _followService.isFollowing(followerId: currentUserId, followedId: widget.userId,);
          _isBlocked = await _blockService.isUserBlocked(checkerId: currentUserId, checkedId: widget.userId,);
        } catch (e) {
          print('Failed to check follow/block status: $e');
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Graphics.showTopDialog(context, "Error", 'Failed to load profile: ${e.toString()}', type: ToastType.error, actionLabel: "Retry", onAction: _loadUserProfile,);
      }
    }
  }

  Future<void> _loadPostVideos({bool reset = false}) async {
    if (_isFetchingMore || (!_hasMoreVideos && !reset)) return;

    if(!reset) setState(() => _isFetchingMore = true);

    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMoreVideos = true;
      });
    }

    try {
      final videos = await ApiRepository.instance.videos.getUserPostedVideos(
        widget.userId,
        limit: _pageSize,
        page: _currentPage,
      );

      setState(() {
        if (reset) {
          _userVideos = videos;
        } else {
          _userVideos.addAll(videos);
        }
        _currentPage++;
        _hasMoreVideos = videos.length == _pageSize;
      });
    } catch (e) {
      print('Failed to load videos: $e');
    } finally {
      if (mounted) setState(() => _isFetchingMore = false);
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

      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followerCount++;
        } else {
          _followerCount--;
        }
      });

      Graphics.showTopDialog(
        context,
        "Success!",
        _isFollowing
            ? 'Following ${_user?.displayName}'
            : 'Unfollowed ${_user?.displayName}',
      );
      eventBus.fire('updatedUser');
      eventBus.fire({
        "userId": widget.userId,
        "isFollow": _isFollowing,
      });
    } catch (e) {
      Graphics.showTopDialog(
        context,
        "Error",
        'Failed to ${_isFollowing ? 'unfollow' : 'follow'}: $e',
        type: ToastType.error,
      );
    } finally {
      setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _toggleBlock() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.userId) return;

    try {
      await Utils.showLoaderWhile(context, () async {
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
          if (_isBlocked && _isFollowing) {
            _isFollowing = false;
          }
        });
      });

      Graphics.showTopDialog(
        context,
        _isBlocked ? "Blocked" : "Unblocked",
        _isBlocked
            ? 'Blocked ${_user?.displayName ?? ""}'
            : 'Unblocked ${_user?.displayName ?? ""}',
        type: ToastType.success,
      );
    } catch (e) {
      Graphics.showTopDialog(
        context,
        "Error!",
        'Failed to ${_isBlocked ? 'unblock' : 'block'}: $e',
        type: ToastType.error,
      );
    }
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
                : 'Are you sure you want to block ${_user?.displayName}? They won\'t be able to see your profile or interact with your content.',
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
    if (_isLoading) return _buildLoadingScaffold();
    if (_user == null) return _buildNotFoundScaffold();

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
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: RefreshIndicator(
                    onRefresh: () => _loadUserProfile(isLoadingShow: false),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildSliverAppBar(isOwnProfile),
                        _buildProfileInfo(isOwnProfile),
                        _buildStatsSection(),
                        _buildTabBar(context),
                        _buildTabContent(),
                        if(_isFetchingMore)
                        SliverToBoxAdapter(
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )

                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 130),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBannerAd(),
              _buildFloatingAvatar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.displayName ?? 'Profile'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotFoundScaffold() {
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

  Widget _buildFloatingAvatar() {
    return Positioned(
      top: 300 - offsetY - 70,
      left: MediaQuery.of(context).size.width / 2 - 100 / 2,
      child: GestureDetector(
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
      ),
    );
  }

  Widget _buildBottomBannerAd() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: const SafeArea(child: BannerAdWidget()),
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

  Widget _buildTabBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[700]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Posts (${_userVideos.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  } 

  Widget _buildTabContent() {
    final videos = _userVideos;

    if (videos.isEmpty) {
      return _buildEmptyVideosState();
    }

    const int videosPerRow = 3;
    int rowsBeforeAd = SettingManager().nativeFrequency;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> children = [];

    for (int i = 0; i < videos.length; i += videosPerChunk) {
      final end = (i + videosPerChunk < videos.length) ? i + videosPerChunk : videos.length;
      final videosChunk = videos.sublist(i, end);

      children.add(
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,

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
            return VideoGridItemWidget(
              key: ValueKey(video.id),
              video: video,
              onTap: () => _openVideoPlayer(video),
            );
          },
        ),
      );

      children.add(const SizedBox(height: 8));
      if (AppLovinAdManager.isMrecAdLoaded) {
        children.add(AppLovinAdManager.mrecAd());
        children.add(const SizedBox(height: 8));
      } else {
        // No ad → add nothing (zero height)
        children.add(const SizedBox.shrink());
      }
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 10),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildEmptyVideosState() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: Center(
          child: EmptySection(
            icon: Icons.video_library_outlined,
            title: 'No videos yet',
            subtitle:
            '${_user?.displayName ?? 'This user'} hasn\'t posted any videos yet.',
          ),
        ),
      ),
    );
  }

  Future<void> _openVideoPlayer(ApiVideo video) async {
    final snapshot = List<ApiVideo>.from(_userVideos);
    final startIndex = snapshot.indexWhere((v) => v.id == video.id);

    AppLovinAdManager.handleScreenOpen(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              video: video,
              allVideos: snapshot,
              initialIndex: startIndex >= 0 ? startIndex : 0,
              user: _user,
            ),
          ),
        );

        if (result != null) {
          print("Returned from video player screen");
          _loadUserProfile(isLoadingShow: false);
        }
      });
    });
  }

}
