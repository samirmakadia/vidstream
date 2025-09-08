import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/follower_following_list_screen.dart';
import 'package:vidstream/screens/settings_screen.dart';
import 'package:vidstream/screens/video_player_screen.dart';
import 'package:vidstream/services/socket_manager.dart';
import '../helper/navigation_helper.dart';
import '../manager/app_open_ad_manager.dart';
import '../utils/graphics.dart';
import '../widgets/custom_image_widget.dart';
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
        _refreshLikedVideos();
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

  @override
  void dispose() {
    _tabController.dispose();
    _videoUploadedSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null) {
        final user = await ApiRepository.instance.auth.getUserProfile(currentUserId);

        List<ApiVideo> videos = [];
        List<ApiVideo> likedVideos = [];

        try {
          videos = await ApiRepository.instance.videos.getUserPostedVideos(currentUserId);
        } catch (videoError) {
          if (videoError.toString().contains('permission-denied')) {
            print('Permission denied for videos - this is likely a Firestore rules issue');
          }
        }

        try {
          likedVideos = await ApiRepository.instance.videos.getUserLikedVideos(currentUserId);
        } catch (likedError) {
          if (likedError.toString().contains('permission-denied')) {
            print('Permission denied for liked videos - this is likely a Firestore rules issue');
          }
        }
        _refreshFollowCounts();
        final updatedVideos = likedVideos.map((video) => video.copyWith(isLiked: true)).toList();
        if (mounted) {
          setState(() {
            _currentUser = user;
            _userVideos = videos;
            _likedVideos = updatedVideos;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to load profile: ${e.toString()}'),
        //     backgroundColor: Theme.of(context).colorScheme.error,
        //     action: SnackBarAction(
        //       label: 'Retry',
        //       onPressed: _loadUserProfile,
        //     ),
        //   ),
        // );
        Graphics.showTopDialog(
          context,
          "Error",
          'Failed to load profile: ${e.toString()}',
          type: ToastType.error,
          actionLabel: "Retry",
          onAction: _loadUserProfile,
        );
      }
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

  Future<void> _refreshLikedVideos() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final likedVideos = await ApiRepository.instance.videos.getUserLikedVideos(currentUserId);
        final updatedVideos = likedVideos.map((video) => video.copyWith(isLiked: true)).toList();
        if (mounted) {
          setState(() {
            _likedVideos = updatedVideos;
          });
        }
      } catch (e) {
        print('Failed to refresh liked videos: $e');
      }
    }
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
    final emptyTitle = _selectedTabIndex == 0 ? 'No videos yet' : 'No liked videos';
    final emptySubtitle = _selectedTabIndex == 0
        ? 'Create your first video using the + button!'
        : 'Like some videos to see them here!';
    final emptyIcon = _selectedTabIndex == 0 ? Icons.video_library_outlined : Icons.favorite_outline;

    if (videos.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 250,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 64, color: Colors.white.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
              if (_selectedTabIndex == 1) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshLikedVideos,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Liked Videos', style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
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
            return VideoGridItemWidget(
              video: video,
              onTap: () => _openVideoPlayer(video),
            );
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

}
