import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/repositories/api_repository.dart';

class SearchService {
  ApiRepository get _apiRepository => ApiRepository.instance;

  // Search videos by query
  Future<List<ApiVideo>> searchVideos(String query, CancelToken? cancelToken, {int limit = 20, int page = 1}) async {
    try {
      final response = await _apiRepository.api.searchVideos(
        query: query,
        limit: limit,
        page: page,
        cancelToken: cancelToken,
      );
      return response?.data ?? [];
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('⚠️ Search request cancelled: ${e.message}');
        return [];
      }
      debugPrint('❌ Error searching videos: $e');
      return [];
    }
  }


  // Search users by query
  Future<List<ApiUser>> searchUsers(String query, CancelToken? cancelToken, {int limit = 20, int page = 1}) async {
    try {
      final response = await _apiRepository.api.searchUsers(
        query: query,
        limit: limit,
        page: page,
        cancelToken: cancelToken
      );
      return response?.data ?? [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get trending videos
  Future<List<ApiVideo>> getTrendingVideos({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiRepository.api.getTrendingVideos(limit: limit,page : page );
      return response?.data ?? [];
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  // Get popular users
  Future<List<ApiUser>> getPopularUsers({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiRepository.api.getPopularUsers(limit: limit,page : page );
      return response?.data ?? [];
    } catch (e) {
      print('Error getting popular users: $e');
      return [];
    }
  }

  // Search videos by category
  Future<List<ApiVideo>> searchVideosByCategory(String category, {int limit = 20}) async {
    try {
      final response = await _apiRepository.api.getVideosByCategory(
        category: category,
        limit: limit,
      );
      return response?.data ?? [];
    } catch (e) {
      print('Error searching videos by category: $e');
      return [];
    }
  }

  // Search videos by tag
  Future<List<ApiVideo>> searchVideosByTag(String tag, {int limit = 20}) async {
    try {
      final response = await _apiRepository.api.getVideosByTag(
        tag: tag,
        limit: limit,
      );
      return response?.data ?? [];
    } catch (e) {
      print('Error searching videos by tag: $e');
      return [];
    }
  }

  // Get recent searches for current user
  Future<List<String>> getRecentSearches() async {
    try {
      return await _apiRepository.api.getRecentSearches();
    } catch (e) {
      print('Error getting recent searches: $e');
      return [];
    }
  }

  // Save search query
  Future<void> saveSearchQuery(String query) async {
    try {
      await _apiRepository.api.saveSearchQuery(query);
    } catch (e) {
      print('Error saving search query: $e');
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    try {
      await _apiRepository.api.clearSearchHistory();
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
}