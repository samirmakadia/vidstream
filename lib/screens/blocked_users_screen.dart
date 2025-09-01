import 'package:flutter/material.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/services/block_service.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/screens/other_user_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockService _blockService = BlockService();
  List<ApiUser> _blockedUsers = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      setState(() => _isLoading = true);
      
      // Get blocked users as a stream and take the first value
      final stream = _blockService.getBlockedUsers(currentUserId);
      final blockedUsers = await stream.first;
      
      if (mounted) {
        setState(() {
          _blockedUsers = blockedUsers.map((user) => ApiUser(
            id: user.uid ?? '',
            userId: user.uid ?? '',
            email: user.email ?? '',
            displayName: user.displayName ?? '',
            profileImageUrl: user.profileImageUrl,
            photoURL: user.photoURL,
            bannerImageUrl: user.bannerImageUrl,
            bio: user.bio,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            createdAt: user.createdAt ?? DateTime.now(),
            updatedAt: user.updatedAt ?? DateTime.now(),
            following: user.following ?? [],
            followers: user.followers ?? [],
            videosCount: user.videosCount ?? 0,
            isGuest: user.isGuest ?? false,
            isFollow: user.isFollow ?? false,
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load blocked users: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(ApiUser user) async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _blockService.unblockUser(
        blockerId: currentUserId,
        blockedId: user.id,
      );
      
      // Remove from local list
      setState(() {
        _blockedUsers.removeWhere((blockedUser) => blockedUser.id == user.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unblocked ${user.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unblock user: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showUnblockConfirmationDialog(ApiUser user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Unblock User',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to unblock ${user.displayName}? They will be able to see your profile and interact with your content again.',
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
                _unblockUser(user);
              },
              child: const Text(
                'Unblock',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Blocked Users'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return _buildBlockedUserCard(user);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 64,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Blocked Users',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t blocked any users yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUserCard(ApiUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        dense: true,
        leading: GestureDetector(
          onTap: () => _navigateToUserProfile(user),
          child: CircleAvatar(
            radius: 20,
            backgroundImage: user.profileImageUrl != null || user.photoURL != null
                ? NetworkImage(user.profileImageUrl ?? user.photoURL!)
                : null,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: (user.profileImageUrl == null && user.photoURL == null)
                ? const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 22,
                  )
                : null,
          ),
        ),
        title: GestureDetector(
          onTap: () => _navigateToUserProfile(user),
          child: Text(
            user.displayName,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        subtitle: user.bio != null && user.bio!.isNotEmpty
            ? Text(
                user.bio!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              ),
              child: Text(
                'BLOCKED',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.more_vert,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              color: Colors.grey[800],
              onSelected: (String value) {
                switch (value) {
                  case 'unblock':
                    _showUnblockConfirmationDialog(user);
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
                const PopupMenuItem<String>(
                  value: 'unblock',
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.green),
                    title: Text(
                      'Unblock',
                      style: TextStyle(color: Colors.green),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}