import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/services/api_service.dart';
import 'package:vidstream/services/auth_service.dart';
import 'dart:async';

class LikeService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  // Toggle like for video
  Future<void> toggleVideoLike(String videoId) async {
    try {
      await _apiService.toggleLike(
        targetId: videoId,
        targetType: 'video',
      );
    } catch (e) {
      throw 'Failed to toggle like: ${e.toString()}';
    }
  }

  // Toggle like for comment
  Future<void> toggleCommentLike(String commentId) async {
    try {
      await _apiService.toggleLike(
        targetId: commentId,
        targetType: 'comment',
      );
    } catch (e) {
      throw 'Failed to toggle comment like: ${e.toString()}';
    }
  }

  // Legacy method for backward compatibility
  Future<void> toggleLike({
    required String userId,
    required String targetId,
    required String targetType,
  }) async {
    try {
      await _apiService.toggleLike(
        targetId: targetId,
        targetType: targetType,
      );
    } catch (e) {
      throw 'Failed to toggle like: ${e.toString()}';
    }
  }

  // Check if video is liked by current user
  Future<bool> isVideoLiked(String videoId) async {
    try {
      return await _apiService.checkIfLiked(
        targetId: videoId,
        targetType: 'video',
      );
    } catch (e) {
      print('Failed to check video like status: $e');
      return false;
    }
  }

  // Check if comment is liked by current user
  Future<bool> isCommentLiked(String commentId) async {
    try {
      return await _apiService.checkIfLiked(
        targetId: commentId,
        targetType: 'comment',
      );
    } catch (e) {
      print('Failed to check comment like status: $e');
      return false;
    }
  }

  // Legacy method for backward compatibility
  Future<bool> hasUserLiked({
    required String userId,
    required String targetId,
    required String targetType,
  }) async {
    try {
      return await _apiService.checkIfLiked(
        targetId: targetId,
        targetType: targetType,
      );
    } catch (e) {
      print('Failed to check like status: $e');
      return false;
    }
  }

  // Get like count for a video (placeholder)
  Future<int> getVideoLikeCount(String videoId) async {
    try {
      // TODO: Implement get like count API call
      // For now, return 0
      return 0;
    } catch (e) {
      print('Failed to get video like count: $e');
      return 0;
    }
  }

  // Get like count for a comment (placeholder)
  Future<int> getCommentLikeCount(String commentId) async {
    try {
      // TODO: Implement get comment like count API call
      // For now, return 0
      return 0;
    } catch (e) {
      print('Failed to get comment like count: $e');
      return 0;
    }
  }

  // Get likes for a target (stream placeholder)
  Stream<List<ApiLike>> getLikes({
    required String targetId,
    required String targetType,
    int limit = 100,
  }) {
    final controller = StreamController<List<ApiLike>>();
    
    // TODO: Implement real-time likes stream or periodic fetching
    controller.add([]); // Return empty list for now
    
    return controller.stream;
  }

  // Get user's liked videos (stream placeholder)
  Stream<List<String>> getUserLikedVideos(String userId) {
    final controller = StreamController<List<String>>();
    
    // TODO: Implement real-time liked videos stream or periodic fetching
    controller.add([]); // Return empty list for now
    
    return controller.stream;
  }
}