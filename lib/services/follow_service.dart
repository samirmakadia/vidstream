import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/services/block_service.dart';
import 'package:vidstream/services/notification_helper.dart';

class FollowService {
  ApiRepository get _apiRepository => ApiRepository.instance;
  late final BlockService _blockService = BlockService();

  // Toggle follow
  Future<void> toggleFollow({
    required String followerId,
    required String followedId,
  }) async {
    if (followerId == followedId) {
      throw 'Cannot follow yourself';
    }

    try {
      // Check if user is blocked
      final isBlocked = await _blockService.isUserBlocked(
        checkerId: followerId,
        checkedId: followedId,
      );

      if (isBlocked) {
        throw 'Cannot follow blocked user';
      }

      // Check current follow status
      final isFollowing = await _apiRepository.api.isFollowing(followedId: followedId);

      if (isFollowing) {
        await _apiRepository.api.unfollowUser(followedId: followedId);
      } else {
        await _apiRepository.api.followUser(followedId: followedId);
      }
    } catch (e) {
      throw 'Failed to toggle follow: $e';
    }
  }

  // Check if following (with followerId parameter)
  Future<bool> isFollowing({
    required String followerId,
    required String followedId,
  }) async {
    try {
      if (followerId == _apiRepository.auth.currentUser?.id) {
        return await _apiRepository.api.isFollowing(followedId: followedId);
      } else {
        // For other users, we might not have this info
        return false;
      }
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Check if current user is following (simplified version)
  Future<bool> isFollowingUser({
    required String followedId,
  }) async {
    final currentUserId = _apiRepository.auth.currentUser?.id;
    if (currentUserId == null) return false;
    
    return isFollowing(followerId: currentUserId, followedId: followedId);
  }

  // Get followers for a user
  Future<List<ApiUser>> getFollowers(String userId) async {
    try {
      final response = await _apiRepository.api.getUserFollowers(userId: userId);
      return response?.data ?? [];
    } catch (e) {
      print('Error getting followers: $e');
      return [];
    }
  }

  // Get following for a user  
  Future<List<ApiUser>> getFollowing(String userId) async {
    try {
      final response = await _apiRepository.api.getUserFollowing(userId: userId);
      return response?.data ?? [];
    } catch (e) {
      print('Error getting following: $e');
      return [];
    }
  }

  // Get follower count
  Future<int> getFollowerCount(String userId) async {
    try {
      final response = await _apiRepository.api.getUserFollowers(userId: userId);
      return response?.data.length ?? 0;
    } catch (e) {
      print('Error getting follower count: $e');
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await _apiRepository.api.getUserFollowing(userId: userId);
      return response?.data.length ?? 0;
    } catch (e) {
      print('Error getting following count: $e');
      return 0;
    }
  }
}