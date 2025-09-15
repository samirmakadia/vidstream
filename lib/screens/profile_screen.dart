import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/screens/follower_following_list_screen.dart';
import 'package:vidmeet/screens/settings_screen.dart';
import 'package:vidmeet/screens/video_player_screen.dart';
import 'package:vidmeet/services/socket_manager.dart';
import '../helper/navigation_helper.dart';
import '../manager/applovin_ad_manager.dart';
import '../manager/setting_manager.dart';
import '../utils/graphics.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/empty_section.dart';
import '../widgets/image_preview_screen.dart';
import '../widgets/professional_bottom_ad.dart';
import '../widgets/video_grid_item_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  ApiUser? _currentUser;
  List<ApiVideo> _userVideos = [];
  List<ApiVideo> _likedVideos = [];
  bool _isLoading = true;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  double offsetY = 0;
  late StreamSubscription _videoUploadedSubscription;
  int _postsPage = 1;
  bool _isFetchingPosts = false;
  bool _hasMorePosts = true;

  int _likedPage = 1;
  bool _isFetchingLiked = false;
  bool _hasMoreLiked = true;

  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadUserProfile();
    _refreshFollowCounts();
    _videoUploadedSubscription = eventBus.on().listen((event) {
      if (event == 'updatedVideo') {
        _loadUserProfile();
      }
      else if (event == 'updatedUser') {
        _loadUserProfile();
      }
    });
  }


  Future<void> _refreshFollowCounts() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final followerCount = await ApiRepository.instance.follows.getFollowerCount(currentUserId);
        final followingCount = await ApiRepository.instance.follows.getFollowingCount(currentUserId);

        if (mounted) {
          setState(() {
            _followerCount = followerCount;
            _followingCount = followingCount;
          });
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null) {
        final user = await ApiRepository.instance.auth.getUserProfile(currentUserId);
        if (!mounted) return;
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
        _loadPosts(refresh: true);
        _loadLiked(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Graphics.showTopDialog(context, "Error", 'Failed to load profile: ${e.toString()}', type: ToastType.error, actionLabel: "Retry", onAction: _loadUserProfile);
      }
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isFetchingPosts) return;

    if (refresh) {
      // Reset state for a fresh load
      setState(() {
        _postsPage = 0;          // Start before first page
        _userVideos.clear();     // Clear old videos
        _hasMorePosts = true;
      });
    }

    if (!_hasMorePosts) return;

    setState(() => _isFetchingPosts = true);

    try {
      final nextPage = _postsPage + 1;
      final newVideos = await ApiRepository.instance.videos
          .getUserPostedVideos(_currentUser!.id, limit: _pageSize, page: nextPage);

      if (!mounted) return;

      setState(() {
        _userVideos.addAll(newVideos);
        _postsPage = nextPage;
        _hasMorePosts = newVideos.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Failed to load posts: $e');
    } finally {
      if (mounted) setState(() => _isFetchingPosts = false);
    }
  }

  Future<void> _loadLiked({bool refresh = false}) async {
    if (_isFetchingLiked) return;

    if (refresh) {
      setState(() {
        _likedPage = 0;
        _likedVideos.clear();
        _hasMoreLiked = true;
      });
    }

    if (!_hasMoreLiked) return;

    setState(() => _isFetchingLiked = true);

    try {
      final nextPage = _likedPage + 1;
      final newVideos = await ApiRepository.instance.videos
          .getUserLikedVideos(_currentUser!.id, limit: _pageSize, page: nextPage);

      if (!mounted) return;

      setState(() {
        _likedVideos.addAll(newVideos.map((v) => v.copyWith(isLiked: true)));
        _likedPage = nextPage;
        _hasMoreLiked = newVideos.length == _pageSize;
      });
    } catch (e) {
      debugPrint('Failed to load liked videos: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLiked = false);
    }
  }

  Future<void> _navigateToSettings() async {
    NavigationHelper.navigateWithAd<bool>(
      context: context,
      destination: SettingsScreen(currentUser: _currentUser),
      onReturn: (result) {
        if (result != null && result) {
          setState(() {
            _loadUserProfile();
          });
        }
      },
    );
  }

  void _navigateToFollowersList(int initialTabIndex) {
    if (_currentUser == null) return;
    NavigationHelper.navigateWithAd<void>(
      context: context,
      destination: FollowerFollowingListScreen(
        userId: _currentUser!.id,
        initialTabIndex: initialTabIndex,
        displayName: _currentUser!.displayName ?? 'User',
      ),
      onReturn: (_) {
        print("Returned from follower/following screen");
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoUploadedSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: ProfessionalBottomAd(
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            setState(() {
              offsetY = scrollInfo.metrics.pixels;
            });
            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
              if (_selectedTabIndex == 0) {
                _loadPosts();
              } else {
                _loadLiked();
              }
            }
            return true;
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await _loadUserProfile();
                  await _refreshFollowCounts();
                },
                child: CustomScrollView(
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),
                    _buildProfileInfoWithoutAvatar(),
                    _buildStatsSection(),
                    _buildTabBar(),
                    _buildTabContent(),
                  ],
                ),
              ),
              Positioned(
                top: 300 - offsetY - 60 ,
                left: MediaQuery.of(context).size.width / 2 - 100 / 2,
                child: _buildFloatingAvatar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      elevation: 0,
      clipBehavior: Clip.none,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16,),
          child: GestureDetector(
            onTap: _navigateToSettings,
            child: Icon(Icons.settings, color: Colors.white, size: 26),
          ),
        )
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          clipBehavior: Clip.none,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_currentUser?.bannerImageUrl != null &&
                  _currentUser!.bannerImageUrl!.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImagePreviewScreen(
                      imageUrl: _currentUser!.bannerImageUrl!,
                      showUploadButton: false,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                // Banner background
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
                  child: _currentUser?.bannerImageUrl != null &&
                      _currentUser!.bannerImageUrl!.isNotEmpty
                      ? CustomImageWidget(
                    imageUrl: _currentUser!.bannerImageUrl!,
                    height: double.infinity,
                    width: double.infinity,
                    cornerRadius: 0,
                    borderWidth: 0,
                    fit: BoxFit.cover,
                  )
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Banner',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } 

  Widget _buildProfileInfoWithoutAvatar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16,  ),
        child: Column(
          children: [
            SizedBox(height: 70,),
            Text(
              _currentUser?.displayName ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (_currentUser?.bio != null) ...[
              Text(
                _currentUser!.bio ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Age from DOB
                if (_currentUser?.dateOfBirth != null) ...[
                  Icon(
                    Icons.cake_outlined,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateTime.now().year - _currentUser!.dateOfBirth!.year} years',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],

                // Separator if both age and gender exist
                if (_currentUser?.dateOfBirth != null && _currentUser?.gender != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '•',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Gender
                if (_currentUser?.gender != null) ...[
                  Icon(
                    _currentUser!.gender == 'male' ? Icons.male :
                    _currentUser!.gender == 'female' ? Icons.female : Icons.person,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentUser!.gender!.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Guest badge
            if (_currentUser?.isGuest == true)
              Container(
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
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAvatar() {
    return GestureDetector(
      onTap: ()
        async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImagePreviewScreen(
                imageUrl: (_currentUser?.profileImageUrl?.isNotEmpty == true)
                    ? _currentUser!.profileImageUrl
                    : _currentUser?.photoURL,
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
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
        child: (_currentUser?.profileImageUrl != null && _currentUser!.profileImageUrl!.isNotEmpty) ||
            (_currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty)
            ? ClipOval(
          child: CustomImageWidget(
            imageUrl: _currentUser?.profileImageUrl?.isNotEmpty == true
                ? _currentUser!.profileImageUrl!
                : _currentUser!.photoURL!,
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

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Videos', _userVideos.length.toString(), onTap: null),
                _buildStatItem('Followers', _followerCount.toString(), onTap: () => _navigateToFollowersList(0)),
                _buildStatItem('Following', _followingCount.toString(), onTap: () => _navigateToFollowersList(1)),
              ],
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
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Posts (${_userVideos.length})'),
                ],
              ),
            ),
            Tab(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_outline, size: 18),
                  const SizedBox(width: 6),
                  Text('Liked (${_likedVideos.length})'),
                ],
              ),
            ),
          ],
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final videos = _selectedTabIndex == 0 ? _userVideos : _likedVideos;
    final bool isFetching = _selectedTabIndex == 0 ? _isFetchingPosts : _isFetchingLiked;
    final bool hasMore = _selectedTabIndex == 0 ? _hasMorePosts : _hasMoreLiked;

    if (videos.isEmpty && !isFetching) {
      return _buildEmptySection();
    }

    const int videosPerRow = 3;
    final int rowsBeforeAd = SettingManager().nativeFrequency;
    final int videosPerChunk = videosPerRow * rowsBeforeAd;

    final List<Widget> children = [];

    // Build chunks of videos with ads in between
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
      }
    }

    if (isFetching) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }

  Future<void> _openVideoPlayer(ApiVideo video) async {
    final videos = _selectedTabIndex == 0 ? _userVideos : _likedVideos;
    AppLovinAdManager.handleScreenOpen(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final  result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) =>  VideoPlayerScreen(
            video: video,
            allVideos: videos,
            user: _currentUser,
          )),
        );
        if (result != null) {
          setState(() {
            if (_selectedTabIndex == 0) {
              _userVideos.removeWhere((v) => v.id == result);
            } else {
              _likedVideos.removeWhere((v) => v.id == result);
            }
          });
          _loadUserProfile();
        }
      });
    });
  }

  Widget _buildEmptySection() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: _selectedTabIndex == 0
            ? EmptySection(
          icon: Icons.video_library_outlined,
          title: 'No videos yet',
          subtitle: 'Create your first video using the + button!',
        )
            : EmptySection(
          icon: Icons.favorite_outline,
          title: 'No liked videos',
          subtitle: 'Like some videos to see them here!',
          refreshText: 'Refresh Liked Videos',
          onRefresh: _loadLiked
          ),
      ),
    );
  }
}
