import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/models/response_model.dart' as response_models;
import 'package:vidmeet/services/api_service.dart';
import 'package:vidmeet/services/auth_service.dart';
import 'dart:async';

class CommentService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  // Get comments for a video
  Future<List<ApiComment>> getVideoComments(String videoId, {int limit = 20}) async {
    try {
      final response = await _apiService.getComments(videoId: videoId, limit: limit);
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get video comments: $e');
      return [];
    }
  }

  // Get comments stream for a video
  Stream<List<ApiComment>> getComments(String videoId, {int limit = 20}) {
    final controller = StreamController<List<ApiComment>>();
    _loadCommentsForVideo(videoId, limit, controller);
    return controller.stream;
  }

  Future<void> _loadCommentsForVideo(String videoId, int limit, StreamController<List<ApiComment>> controller) async {
    try {
      final comments = await getVideoComments(videoId, limit: limit);
      final organized = _organizeComments(comments);
      controller.add(organized);
    } catch (e) {
      controller.addError(e);
    }
  }

  // Organize comments to show replies under parent comments
  List<ApiComment> _organizeComments(List<ApiComment> comments) {
    final organized = <ApiComment>[];
    final parentComments = comments.where((c) => c.parentCommentId == null).toList();
    
    for (final parent in parentComments) {
      organized.add(parent);
      final replies = comments.where((c) => c.parentCommentId == parent.id).toList();
      organized.addAll(replies);
    }
    
    return organized;
  }

  // Create a new comment (legacy method name)
  Future<String> addComment(ApiComment comment) async {
    try {
      final createdComment = await _apiService.createComment(
        videoId: comment.videoId,
        text: comment.text,
        parentCommentId: comment.parentCommentId,
      );
      return createdComment?.id ?? '';
    } catch (e) {
      throw 'Failed to add comment: ${e.toString()}';
    }
  }

  // Create a new comment
  Future<ApiComment?> createComment({
    required String videoId,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      return await _apiService.createComment(
        videoId: videoId,
        text: text,
        parentCommentId: parentCommentId,
      );
    } catch (e) {
      throw 'Failed to create comment: ${e.toString()}';
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId, [String? videoId]) async {
    try {
      await _apiService.deleteComment(commentId);
    } catch (e) {
      throw 'Failed to delete comment: ${e.toString()}';
    }
  }

  // Get replies for a comment
  Future<List<ApiComment>> getCommentReplies(String commentId, {int limit = 20}) async {
    try {
      final response = await _apiService.getComments(
        videoId: '', // Not needed for replies
        parentCommentId: commentId,
        limit: limit,
      );
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get comment replies: $e');
      return [];
    }
  }

  // Get replies stream for a comment
  Stream<List<ApiComment>> getCommentRepliesStream(String commentId, {int limit = 20}) {
    final controller = StreamController<List<ApiComment>>();
    _loadRepliesForComment(commentId, limit, controller);
    return controller.stream;
  }

  Future<void> _loadRepliesForComment(String commentId, int limit, StreamController<List<ApiComment>> controller) async {
    try {
      final replies = await getCommentReplies(commentId, limit: limit);
      controller.add(replies);
    } catch (e) {
      controller.addError(e);
    }
  }

  // Update comment (placeholder)
  Future<void> updateComment(ApiComment comment) async {
    try {
      // TODO: Implement comment update API call
      throw 'Comment update not implemented yet';
    } catch (e) {
      throw 'Failed to update comment: ${e.toString()}';
    }
  }

  // Get single comment by ID (placeholder)
  Future<ApiComment?> getCommentById(String commentId) async {
    try {
      // TODO: Implement get comment by ID API call
      // For now, return null
      return null;
    } catch (e) {
      print('Failed to get comment: $e');
      return null;
    }
  }

  // Get comment count for a video (placeholder)
  Future<int> getVideoCommentCount(String videoId) async {
    try {
      // TODO: Implement get comment count API call
      // For now, return 0
      return 0;
    } catch (e) {
      print('Failed to get video comment count: $e');
      return 0;
    }
  }
}