import 'package:flutter/material.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/auth_screen.dart';
import 'package:vidstream/services/demo_data_service.dart';
import 'package:vidstream/utils/auth_utils.dart';
import 'package:vidstream/screens/follower_following_list_screen.dart';
import 'package:vidstream/screens/blocked_users_screen.dart';
import 'package:vidstream/screens/settings_screen.dart';
import 'package:vidstream/screens/video_player_screen.dart';

import '../widgets/common_app_dialog.dart';
import '../widgets/custom_image_widget.dart';

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


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadUserProfile();
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
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUserId = ApiRepository.instance.auth.currentUser?.id;
      if (currentUserId != null) {
        print('Loading profile for user: $currentUserId');

        // Load user profile first
        final user = await ApiRepository.instance.auth.getUserProfile(currentUserId);

        // Try to load videos with error handling
        List<ApiVideo> videos = [];
        List<ApiVideo> likedVideos = [];

        try {
          videos = await ApiRepository.instance.videos.getUserPostedVideos(currentUserId);
          print('Loaded ${videos.length} user videos');
        } catch (videoError) {
          print('Failed to load user videos: $videoError');
          if (videoError.toString().contains('permission-denied')) {
            print('Permission denied for user videos - this is likely a Firestore rules issue');
          }
        }

        try {
          likedVideos = await ApiRepository.instance.videos.getUserLikedVideos(currentUserId);
          print('Loaded ${likedVideos.length} liked videos');
        } catch (likedError) {
          print('Failed to load liked videos: $likedError');
          if (likedError.toString().contains('permission-denied')) {
            print('Permission denied for liked videos - this is likely a Firestore rules issue');
          }
        }

        if (mounted) {
          setState(() {
            _currentUser = user;
            _userVideos = videos;
            _likedVideos = likedVideos;
            _isLoading = false;
          });
        }

        // Show info message if no videos could be loaded due to permissions
        if (videos.isEmpty && likedVideos.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to load videos due to permission issues. Try creating sample data.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Create Sample',
                onPressed: _createSampleVideos,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Profile loading error: $e');
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


  Future<void> _signOut() async {
    bool confirmed = await CommonDialog.showConfirmationDialog(
      context: context,
      title: "Sign Out",
      content:
      "Are you sure you want to sign out of your account?",
      confirmText: "Sign Out",
      confirmColor: Colors.orange,
    );
    if (!confirmed) return;
    try {
      await ApiRepository.instance.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }


  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentUser: _currentUser),
      ),
    );
  }

  Future<void> _createSampleVideos() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating sample videos...'),
          backgroundColor: Colors.blue,
        ),
      );

      await DemoDataService.createSampleVideos();
      await _loadUserProfile(); // Refresh to show new videos

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample videos created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create sample videos: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _createSampleLikes() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating sample likes...'),
          backgroundColor: Colors.blue,
        ),
      );

      await DemoDataService.createSampleLikes();
      await _loadUserProfile(); // Refresh to show liked videos

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample likes created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create sample likes: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _refreshLikedVideos() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final likedVideos = await ApiRepository.instance.videos.getUserLikedVideos(currentUserId);
        if (mounted) {
          setState(() {
            _likedVideos = likedVideos;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refreshed: ${likedVideos.length} liked videos found'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Failed to refresh liked videos: $e');
      }
    }
  }

  void _navigateToFollowersList(int initialTabIndex) {
    if (_currentUser == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowerFollowingListScreen(
          userId: _currentUser!.id,
          initialTabIndex: initialTabIndex,
          displayName: _currentUser!.displayName ?? 'User',
        ),
      ),
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
      body:
      NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          setState(() {
            offsetY = scrollInfo.metrics.pixels;
          });
          return true;
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main scroll view
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
        // PopupMenuButton<String>(
        //   icon: const Icon(Icons.more_vert, color: Colors.white),
        //   onSelected: (value) {
        //     switch (value) {
        //       case 'settings':
        //         _navigateToSettings();
        //         break;
        //       case 'sample':
        //         _createSampleVideos();
        //         break;
        //       case 'likes':
        //         _createSampleLikes();
        //         break;
        //       case 'refresh':
        //         _refreshLikedVideos();
        //         break;
        //       case 'follows':
        //         _createSampleFollows();
        //         break;
        //       case 'debug':
        //         _showDebugInfo();
        //         break;
        //       case 'logout':
        //         _signOut();
        //         break;
        //     }
        //   },
        //   itemBuilder: (context) => [
        //     const PopupMenuItem(
        //       value: 'settings',
        //       child: Row(
        //         children: [
        //           Icon(Icons.settings, size: 20),
        //           SizedBox(width: 8),
        //           Text('Settings'),
        //         ],
        //       ),
        //     ),
        //     if (_userVideos.isEmpty) ...[
        //       const PopupMenuItem(
        //         value: 'sample',
        //         child: Row(
        //           children: [
        //             Icon(Icons.video_library, size: 20),
        //             SizedBox(width: 8),
        //             Text('Add Sample Videos'),
        //           ],
        //         ),
        //       ),
        //     ],
        //     if (_likedVideos.isEmpty) ...[
        //       const PopupMenuItem(
        //         value: 'likes',
        //         child: Row(
        //           children: [
        //             Icon(Icons.favorite, size: 20),
        //             SizedBox(width: 8),
        //             Text('Add Sample Likes'),
        //           ],
        //         ),
        //       ),
        //     ],
        //     const PopupMenuItem(
        //       value: 'refresh',
        //       child: Row(
        //         children: [
        //           Icon(Icons.refresh, size: 20),
        //           SizedBox(width: 8),
        //           Text('Refresh Liked Videos'),
        //         ],
        //       ),
        //     ),
        //     const PopupMenuItem(
        //       value: 'follows',
        //       child: Row(
        //         children: [
        //           Icon(Icons.people, size: 20),
        //           SizedBox(width: 8),
        //           Text('Add Sample Follows'),
        //         ],
        //       ),
        //     ),
        //     const PopupMenuItem(
        //       value: 'debug',
        //       child: Row(
        //         children: [
        //           Icon(Icons.bug_report, size: 20),
        //           SizedBox(width: 8),
        //           Text('Debug Info'),
        //         ],
        //       ),
        //     ),
        //     const PopupMenuItem(
        //       value: 'logout',
        //       child: Row(
        //         children: [
        //           Icon(Icons.logout, size: 20),
        //           SizedBox(width: 8),
        //           Text('Sign Out'),
        //         ],
        //       ),
        //     ),
        //   ],
        // ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          clipBehavior: Clip.none,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Banner background
              GestureDetector(
                onTap: _navigateToSettings,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: _currentUser?.bannerImageUrl != null
                      ? Image.network(
                    _currentUser!.bannerImageUrl!,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
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
    );
  }

  Widget _buildProfileInfoWithoutAvatar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16,  ),
        child: Column(
          children: [
            SizedBox(height: 50,),
            const SizedBox(height: 30),

            // User Name
            Text(
              _currentUser?.displayName ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Bio
            if (_currentUser?.bio != null) ...[
              Text(
                _currentUser!.bio!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],

            // Date of Birth and Gender
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
      onTap: _navigateToSettings,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
            child: CircleAvatar(
              radius: 46,
              backgroundImage: _currentUser?.profileImageUrl != null || _currentUser?.photoURL != null
                  ? NetworkImage(_currentUser!.profileImageUrl ?? _currentUser!.photoURL!)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: (_currentUser?.profileImageUrl == null && _currentUser?.photoURL == null)
                  ? const Icon(
                Icons.person,
                size: 40,
                color: Colors.white,
              )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
            const SizedBox(height: 16),
            // Settings Button
            // SizedBox(
            //   width: double.infinity,
            //   height: 45,
            //   child: ElevatedButton.icon(
            //     onPressed: _navigateToSettings,
            //     icon: const Icon(Icons.settings, size: 18),
            //     label: const Text('Settings'),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Colors.grey[800],
            //       foregroundColor: Colors.white,
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(22),
            //       ),
            //     ),
            //   ),
            // ),
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
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
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
          labelColor: Colors.white,
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

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: videos.isEmpty
          ? SliverToBoxAdapter(
        child: Container(
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
                  label: const Text('Refresh Liked Videos'),
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
      )
          : SliverLayoutBuilder(
        builder: (context, constraints) {
          final spacing = 8 * (3 - 1);
          final itemWidth = (constraints.crossAxisExtent - spacing) / 3;
          final itemHeight = itemWidth / 0.7;

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final video = videos[index];
                return _buildVideoGridItem(video, itemWidth, itemHeight);
              },
              childCount: videos.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoGridItem(ApiVideo video, double width, double height) {
    return InkWell(
      onTap: () => _openVideoPlayer(video),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomImageWidget(
              imageUrl: video.thumbnailUrl,
              height: height,
              width: width,
              cornerRadius: 12,
            ),

            // Simple play button
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Simple video stats
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    );
  }

  void _openVideoPlayer(ApiVideo video) {
    final videos = _selectedTabIndex == 0 ? _userVideos : _likedVideos;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          video: video,
          allVideos: videos,
        ),
      ),
    );
  }
}

