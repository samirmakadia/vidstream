import 'package:flutter/material.dart';
import 'package:vidmeet/manager/setting_manager.dart';
import 'package:vidmeet/services/follow_service.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/repositories/api_repository.dart';
import 'package:vidmeet/screens/other_user_profile_screen.dart';
import '../helper/navigation_helper.dart';
import '../manager/applovin_ad_manager.dart';
import '../services/socket_manager.dart';
import '../utils/graphics.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/empty_section.dart';
import '../widgets/professional_bottom_ad.dart';

class FollowerFollowingListScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex;
  final String displayName;

  const FollowerFollowingListScreen({
    super.key,
    required this.userId,
    required this.initialTabIndex,
    required this.displayName,
  });

  @override
  State<FollowerFollowingListScreen> createState() => _FollowerFollowingListScreenState();
}

class _FollowerFollowingListScreenState extends State<FollowerFollowingListScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FollowService _followService = FollowService();
  String? _currentUserId;
  final Set<String> _loadingFollowUsers = {};
  bool _isFirstLoadFollowers = true;
  bool _isFirstLoadFollowing = true;
  final ScrollController _followersController = ScrollController();
  final ScrollController _followingController = ScrollController();
  bool _hasMoreFollowers = true;
  bool _hasMoreFollowing = true;

  int _followersPage = 1;
  int _followingPage = 1;
  final int _pageSize = 20;
  final List<ApiUser> _followers = [];
  final List<ApiUser> _following = [];
  bool _isFetchingFollowers = false;
  bool _isFetchingFollowing = false;
  bool _isFetchingFollowersPagination = false;
  bool _isFetchingFollowingPagination = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _currentUserId = ApiRepository.instance.auth.currentUser?.id;

    _fetchFollowers();
    _fetchFollowing();

    _followersController.addListener(() {
      if (_followersController.position.pixels >=
          _followersController.position.maxScrollExtent - 200 &&
          !_isFetchingFollowers &&
          _hasMoreFollowers) {
        _fetchFollowers();
      }
    });

    _followingController.addListener(() {
      if (_followingController.position.pixels >=
          _followingController.position.maxScrollExtent - 200 &&
          !_isFetchingFollowing &&
          _hasMoreFollowing) {
        _fetchFollowing();
      }
    });
  }

  Future<void> _fetchFollowers({bool refresh = false}) async {
    if (refresh) {
      _followersPage = 1;
      _hasMoreFollowers = true;
    } else {
      if (!_hasMoreFollowers || _isFetchingFollowersPagination) return;
      setState(() => _isFetchingFollowersPagination = true);
    }

    if (refresh) setState(() => _isFetchingFollowers = true);

    final newData = await _followService.getFollowers(
      widget.userId,
      page: _followersPage,
      limit: _pageSize,
    );

    setState(() {
      if (refresh) _followers.clear();
      _followers.addAll(newData);

      _hasMoreFollowers = newData.length == _pageSize;
      if (_hasMoreFollowers) _followersPage++;

      if (refresh) _isFetchingFollowers = false;
      else _isFetchingFollowersPagination = false;

      _isFirstLoadFollowers = false;
    });
  }

  Future<void> _fetchFollowing({bool refresh = false}) async {
    if (refresh) {
      _followingPage = 1;
      _hasMoreFollowing = true;
    } else {
      if (!_hasMoreFollowing || _isFetchingFollowingPagination) return;
      setState(() => _isFetchingFollowingPagination = true);
    }

    if (refresh) setState(() => _isFetchingFollowing = true);

    final newData = await _followService.getFollowing(
      widget.userId,
      page: _followingPage,
      limit: _pageSize,
    );

    setState(() {
      if (refresh) _following.clear();
      _following.addAll(newData);

      _hasMoreFollowing = newData.length == _pageSize;
      if (_hasMoreFollowing) _followingPage++;

      if (refresh) _isFetchingFollowing = false;
      else _isFetchingFollowingPagination = false;

      _isFirstLoadFollowing = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: ProfessionalBottomAd(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFollowersList(),
              _buildFollowingList(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(widget.displayName),
      centerTitle: true,
      bottom: TabBar(
        dividerColor: Colors.grey.withOpacity(0.5),
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: const [
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    if (_isFirstLoadFollowers && _followers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_followers.isEmpty) {
      return EmptySection(
        icon: Icons.people_outline,
        title: 'No followers yet',
        subtitle: 'When people follow this account, they\'ll show up here.',
      );
    }

    final List<Widget> items = [];
    final int frequency = SettingManager().nativeFrequency;

    for (int i = 0; i < _followers.length; i++) {
      items.add(_buildUserListItem(_followers[i]));

      // Regular ads at intervals
      if ((i + 1) % frequency == 0 && AppLovinAdManager.isMrecAdLoaded) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppLovinAdManager.mrecAd(),
        ));
      }
    }

    // If list is shorter than frequency, show ad at end
    if (_followers.length < frequency && AppLovinAdManager.isMrecAdLoaded) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppLovinAdManager.mrecAd(),
      ));
    }

    if (_isFetchingFollowersPagination) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ));
    }

    return RefreshIndicator(
      onRefresh: () => _fetchFollowers(refresh: true),
      child: ListView(
        controller: _followersController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: items,
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isFirstLoadFollowing && _following.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_following.isEmpty) {
      return EmptySection(
        icon: Icons.person_add_outlined,
        title: 'Not following anyone yet',
        subtitle: 'When this account follows people, they\'ll show up here.',
      );
    }

    final List<Widget> items = [];
    final int frequency = SettingManager().nativeFrequency;

    for (int i = 0; i < _following.length; i++) {
      items.add(_buildUserListItem(_following[i]));

      // Regular ads at intervals
      if ((i + 1) % frequency == 0 && AppLovinAdManager.isMrecAdLoaded) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppLovinAdManager.mrecAd(),
        ));
      }
    }

    if (_following.length < frequency && AppLovinAdManager.isMrecAdLoaded) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppLovinAdManager.mrecAd(),
      ));
    }

    if (_isFetchingFollowingPagination) {
      items.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ));
    }

    return RefreshIndicator(
      onRefresh: () => _fetchFollowing(refresh: true),
      child: ListView(
        controller: _followingController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: items,
      ),
    );
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

  Widget _buildUserListItem(ApiUser user) {
    final isCurrentUser = _currentUserId == user.id;

    return GestureDetector(
      onTap: () => _navigateToUserProfile(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Profile Picture
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) ||
                  (user.photoURL != null && user.photoURL!.isNotEmpty) ?
              CustomImageWidget(
                imageUrl: user.profileImageUrl ?? user.photoURL ?? '',
                height: 55,
                width: 55,
                cornerRadius: 24,
              ) :
               CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.white,
                      )
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    Text(
                      user.bio!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      user.isGuest == true ? 'Guest User' : 'VidMeet User',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isCurrentUser)_loadingFollowUsers.contains(user.id)
                  ? Padding(
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: Colors.white,
                  ),
                ),
              ) : FutureBuilder<bool>(
                future: _followService.isFollowing(
                  followerId: _currentUserId!,
                  followedId: user.id,
                ),
                builder: (context, snapshot) {
                  final isFollowing = snapshot.data ?? false;
                  final isLoading = _loadingFollowUsers.contains(user.id) || snapshot.connectionState == ConnectionState.waiting;

                  return PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    color: Colors.grey[800],
                    onSelected: (String value) async {
                      switch (value) {
                        case 'toggle_follow':
                          if (!isLoading) {
                            await _toggleFollow(user.id);
                          }
                          break;
                        case 'view_profile':
                          _navigateToUserProfile(user);
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'view_profile',
                        child: ListTile(
                          leading: Icon(Icons.person, color: Colors.blue),
                          title: Text(
                            'View Profile',
                            style: TextStyle(color: Colors.blue),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle_follow',
                        child: ListTile(
                          leading: isLoading
                              ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Icon(
                            isFollowing ? Icons.person_remove : Icons.person_add,
                            color: isFollowing ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            isLoading
                                ? 'Loading...'
                                : isFollowing
                                ? 'Unfollow'
                                : 'Follow',
                            style: TextStyle(
                              color: isFollowing ? Colors.red : Colors.green,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(String targetUserId) async {
    if (_currentUserId == null) return;

    setState(() {
      _loadingFollowUsers.add(targetUserId);
    });

    try {
      final isCurrentlyFollowing = await _followService.isFollowing(
        followerId: _currentUserId!,
        followedId: targetUserId,
      );
      await _followService.toggleFollow(
        followerId: _currentUserId!,
        followedId: targetUserId,
      );
      eventBus.fire('updatedUser');
      final newIsFollow = !isCurrentlyFollowing;
      eventBus.fire({
        "userId": targetUserId,
        "isFollow": newIsFollow,
      });
      _fetchFollowers(refresh: true);
      _fetchFollowing(refresh: true);
    } catch (e) {
      if (mounted) {
        Graphics.showTopDialog(
          context,
          "Error",
          'Failed to update follow status: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingFollowUsers.remove(targetUserId);
        });
      }
    }
  }

}