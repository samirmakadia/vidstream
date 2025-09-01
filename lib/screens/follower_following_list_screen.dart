import 'package:flutter/material.dart';
import 'package:vidstream/services/follow_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/screens/other_user_profile_screen.dart';

import '../services/socket_manager.dart';

class FollowerFollowingListScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex; // 0 for followers, 1 for following
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

class _FollowerFollowingListScreenState extends State<FollowerFollowingListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FollowService _followService = FollowService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _currentUserId = ApiRepository.instance.auth.currentUser?.id;
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
      appBar: AppBar(
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
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(),
          _buildFollowingList(),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    return FutureBuilder<List<ApiUser>>(
      future: _followService.getFollowers(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Failed to load followers: ${snapshot.error}');
        }

        final followers = snapshot.data ?? [];

        if (followers.isEmpty) {
          return _buildEmptyWidget(
            icon: Icons.people_outline,
            title: 'No followers yet',
            subtitle: 'When people follow this account, they\'ll show up here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final user = followers[index];
            return _buildUserListItem(user);
          },
        );
      },
    );
  }

  Widget _buildFollowingList() {
    return FutureBuilder<List<ApiUser>>(
      future: _followService.getFollowing(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Failed to load following: ${snapshot.error}');
        }

        final following = snapshot.data ?? [];

        if (following.isEmpty) {
          return _buildEmptyWidget(
            icon: Icons.person_add_outlined,
            title: 'Not following anyone yet',
            subtitle: 'When this account follows people, they\'ll show up here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: following.length,
          itemBuilder: (context, index) {
            final user = following[index];
            return _buildUserListItem(user);
          },
        );
      },
    );
  }

  void _navigateToUserProfile(ApiUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OtherUserProfileScreen(
          userId: user.id,
          displayName: user.displayName,
        ),
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
              child: CircleAvatar(
                radius: 24,
                backgroundImage: user.profileImageUrl != null || user.photoURL != null
                    ? NetworkImage(user.profileImageUrl ?? user.photoURL!)
                    : null,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: (user.profileImageUrl == null && user.photoURL == null)
                    ? Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // User Info
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

            // Follow/Unfollow popup menu
            if (!isCurrentUser)
              FutureBuilder<bool>(
                future: _followService.isFollowing(
                  followerId: _currentUserId!,
                  followedId: user.id,
                ),
                builder: (context, snapshot) {
                  final isFollowing = snapshot.data ?? false;
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                            setState(() {});
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
                          leading: Icon(
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
            // if (!isCurrentUser) ...[
            //   const SizedBox(width: 12),
            //   GestureDetector(
            //     onTap: () {}, // Prevent navigation when tapping follow button
            //     child: _buildFollowButton(user.id),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(String targetUserId) {
    if (_currentUserId == null) {
      return Container(); // Don't show follow button if not authenticated
    }

    return FutureBuilder<bool>(
      future: _followService.isFollowing(
        followerId: _currentUserId!,
        followedId: targetUserId,
      ),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SizedBox(
          width: 100,
          height: 36,
          child: ElevatedButton(
            onPressed: isLoading ? null : () => _toggleFollow(targetUserId),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing 
                  ? Colors.grey[700] 
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow(String targetUserId) async {
    if (_currentUserId == null) return;

    try {
      await _followService.toggleFollow(
        followerId: _currentUserId!,
        followedId: targetUserId,
      );
      eventBus.fire('updatedUser');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update follow status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}), // Trigger rebuild
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}