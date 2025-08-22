import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/repositories/api_repository.dart';

class BlockService {
  ApiRepository get _apiRepository => ApiRepository.instance;

  // Block a user
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    if (blockerId == blockedId) {
      throw 'Cannot block yourself';
    }

    try {
      await _apiRepository.api.blockUser(blockedId);
    } catch (e) {
      throw 'Failed to block user: $e';
    }
  }

  // Unblock a user
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _apiRepository.api.unblockUser(blockedId);
    } catch (e) {
      throw 'Failed to unblock user: $e';
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked({
    required String checkerId,
    required String checkedId,
  }) async {
    try {
      return await _apiRepository.api.isUserBlocked(checkerId: checkerId, checkedId: checkedId);
    } catch (e) {
      print('Error checking block status: $e');
      return false;
    }
  }

  // Get list of blocked users for a user
  Stream<List<ApiUser>> getBlockedUsers(String userId) async* {
    try {
      final response = await _apiRepository.api.getBlockedUsers();
      yield response?.data ?? [];
    } catch (e) {
      print('Error getting blocked users: $e');
      yield [];
    }
  }

  // Get list of users who blocked this user  
  Stream<List<ApiUser>> getBlockedByUsers(String userId) async* {
    try {
      // This might not be available in API for privacy reasons
      yield [];
    } catch (e) {
      print('Error getting blocked by users: $e');
      yield [];
    }
  }

  // Check if two users have blocked each other
  Future<bool> areUsersBlocked({
    required String userId1, 
    required String userId2,
  }) async {
    try {
      // Check both directions
      if (userId1 == ApiRepository.instance.auth.currentUser?.id) {
        return await isUserBlocked(checkerId: userId1, checkedId: userId2);
      } else if (userId2 == ApiRepository.instance.auth.currentUser?.id) {
        return await isUserBlocked(checkerId: userId2, checkedId: userId1);
      }
      return false;
    } catch (e) {
      print('Error checking mutual block status: $e');
      return false;
    }
  }
}