import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/services/api_service.dart';
import 'package:vidmeet/services/auth_service.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../manager/session_manager.dart';

class VideoService {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  final StreamController<List<ApiVideo>> _videosController = StreamController<List<ApiVideo>>.broadcast();
  
  List<ApiVideo> _cachedVideos = [];
  bool _isLoading = false;

  // Get all videos with pagination
  Stream<List<ApiVideo>> getVideos({int limit = 20}) {
    _loadVideos(limit: limit);
    return _videosController.stream;
  }
  
  // Load videos from API
  Future<void> _loadVideos({int limit = 20, bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    _isLoading = true;
    try {
      final response = await _apiService.getVideos(limit: limit);
      if (response != null) {
        _cachedVideos = response.data;
        _videosController.add(_cachedVideos);
      }
    } catch (e) {
      print('Error loading videos: $e');
      _videosController.addError(e);
    } finally {
      _isLoading = false;
    }
  }

  // Get all videos as Future for one-time fetch
  Future<List<ApiVideo>> getVideosOnce({int limit = 20}) async {
    try {
      final response = await _apiService.getVideos(limit: limit);
      final videos = response?.data ?? [];
      return videos;
    } catch (e) {
      print('Failed to get videos: $e');
      return [];
    }
  }


  // Get user videos as Future
  Future<List<ApiVideo>> getUserVideos(String userId, {int limit = 20}) async {
    try {
      final response = await _apiService.getVideos(userId: userId, limit: limit);
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get user videos: $e');
      return [];
    }
  }

  Future<List<ApiVideo>> getUserPostedVideos(String userId) async {
    try {
      final response = await _apiService.getPostedVideos(userId: userId);
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get user videos: $e');
      return [];
    }
  }

  // Get videos by user
  Stream<List<ApiVideo>> getVideosByUser(String userId, {int limit = 20}) {
    final controller = StreamController<List<ApiVideo>>();
    _loadUserVideos(userId, limit, controller);
    return controller.stream;
  }
  
  Future<void> _loadUserVideos(String userId, int limit, StreamController<List<ApiVideo>> controller) async {
    try {
      final videos = await getUserVideos(userId, limit: limit);
      controller.add(videos);
    } catch (e) {
      controller.addError(e);
    }
  }

  // Get videos by category
  Stream<List<ApiVideo>> getVideosByCategory(String category, {int limit = 20}) {
    final controller = StreamController<List<ApiVideo>>();
    _loadVideosByCategory(category, limit, controller);
    return controller.stream;
  }
  
  Future<void> _loadVideosByCategory(String category, int limit, StreamController<List<ApiVideo>> controller) async {
    try {
      final response = await _apiService.getVideos(category: category, limit: limit);
      controller.add(response?.data ?? []);
    } catch (e) {
      controller.addError(e);
    }
  }

  // Get single video by ID
  Future<ApiVideo?> getVideoById(String videoId) async {
    try {
      return await _apiService.getVideoById(videoId);
    } catch (e) {
      throw 'Failed to get video: ${e.toString()}';
    }
  }

  // Create video (for demo purposes)
  Future<ApiVideo?> createVideo({
    required String title,
    required String description,
    required String category,
    List<String>? tags,
    bool isPublic = true,
  }) async {
    try {
      // For demo purposes, create a sample video
      final video = ApiVideo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        thumbnailUrl: 'https://picsum.photos/400/300',
        videoUrl: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        userId: _authService.currentUser?.id ?? 'demo_user',
        category: category,
        tags: tags ?? [],
        isPublic: isPublic,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Add to cached videos
      _cachedVideos.insert(0, video);
      _videosController.add(_cachedVideos);
      
      return video;
    } catch (e) {
      throw 'Failed to create video: ${e.toString()}';
    }
  }

  // Upload video
  Future<ApiVideo?> uploadVideo({
    required String videoPath,
    required String thumbnailPath,
    required String title,
    required String description,
    // required String category,
    required double duration,
    List<String>? tags,
    bool isPublic = true,
  }) async {
    try {
      return await _apiService.uploadVideo(
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        title: title,
        description: description,
        // category: category,
        duration: duration,
        tags: tags,
        isPublic: isPublic,
      );
    } catch (e,s) {
      print('Error uploading video: $e');
      print('Error uploading video: $s');
      throw 'Failed to upload video: ${e.toString()}';
    }
  }

  // Upload a file to /helper/upload
  Future<ApiCommonFile?> uploadCommonFile({
    required String filePath,
    String type = "post",
  }) async {
    try {
      return await _apiService.uploadCommonFile(
        videoPath: filePath,
        type: type,
      );
    } catch (e) {
      throw 'Failed to upload file: ${e.toString()}';
    }
  }

  Future<ApiCommonFile?> uploadCommonImageFile({
    required String filePath,
    String type = "post",
  }) async {
    try {
      return await _apiService.uploadCommonImageFile(
        imagePath: filePath,
        type: type,
      );
    } catch (e) {
      throw 'Failed to upload file: ${e.toString()}';
    }
  }


  // Update video (placeholder - implement based on your API)
  Future<void> updateVideo(ApiVideo video) async {
    try {
      // TODO: Implement video update API call
      throw 'Video update not implemented yet';
    } catch (e) {
      throw 'Failed to update video: ${e.toString()}';
    }
  }

  // Delete video
  Future<void> deleteVideo(String videoId) async {
    try {
      await _apiService.deleteVideo(videoId);
    } catch (e) {
      throw 'Failed to delete video: ${e.toString()}';
    }
  }

  // Increment view count
  Future<void> incrementViewCount(String videoId, {required int watchTime, required double watchPercentage}) async {
    try {
      String country = "Unknown";
      String region = "Unknown";
      String city = "Unknown";
      double? latitude;
      double? longitude;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
          throw Exception("Location permission denied");
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        latitude = position.latitude;
        longitude = position.longitude;
        List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
        Placemark place = placemarks.first;
        country = place.country ?? "Unknown";
        region = place.administrativeArea ?? "Unknown";
        city = place.locality ?? "Unknown";

      } catch (e) {
        final response = await http.get(Uri.parse("https://ipapi.co/json/"));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          country = data["country_name"] ?? "Unknown";
          region = data["region"] ?? "Unknown";
          city = data["city"] ?? "Unknown";
          latitude = double.tryParse(data["latitude"]?.toString() ?? "");
          longitude = double.tryParse(data["longitude"]?.toString() ?? "");
        }
      }

      final sessionId = SessionManager().sessionId;

      await _apiService.trackVideoView(
        videoId: videoId,
        watchTime: watchTime,
        watchPercentage: watchPercentage,
        sessionId: sessionId,
        country: country,
        region: region,
        city: city,
        longitude: longitude,
        latitude: latitude,
      );
    } catch (e, stack) {
    }
  }

  // Search videos
  Future<List<ApiVideo>> searchVideos(String query, {int limit = 20}) async {
    try {
      final response = await _apiService.searchVideos(query: query, limit: limit);
      return response?.data ?? [];
    } catch (e) {
      return [];
    }
  }
  
  // Get trending videos
  Future<List<ApiVideo>> getTrendingVideos() async {
    try {
      // TODO: Implement trending videos API call based on your backend
      // For now, return regular videos
      final response = await _apiService.getVideos(limit: 50);
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get trending videos: $e');
      return [];
    }
  }

  // Get videos that user has liked
  Future<List<ApiVideo>> getUserLikedVideos(String userId) async {
    try {
      final response = await _apiService.getUserLikedVideos(userId: userId);
      return response?.data ?? [];
    } catch (e) {
      print('Failed to get liked videos: $e');
      return [];
    }
  }

  // Refresh videos
  Future<void> refreshVideos({int limit = 20}) async {
    await _loadVideos(limit: limit, refresh: true);
  }
  
  // Dispose resources
  void dispose() {
    _videosController.close();
  }
}

