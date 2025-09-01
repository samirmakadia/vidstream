import 'package:dio/dio.dart';
import '../models/response_model.dart' as response_models;
import '../models/api_models.dart';
import '../services/http_client.dart';
import '../services/error_handler.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final HttpClient _httpClient = HttpClient();

  Future<void> initialize() async {
    await _httpClient.initialize();
  }

  // Auth endpoints
  Future<response_models.AuthResponse?> login({
    required String email,
    required String password,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
        fromJson: (json) => response_models.AuthResponse.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        // Store tokens in HTTP client
        final authData = response.data!;
        _httpClient.setTokens(authData.accessToken, authData.refreshToken);
        return authData;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.AuthResponse?> register({
    required String email,
    required String password,
    required String displayName,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'display_name': displayName,
          'gender': gender,
          'date_of_birth': dateOfBirth?.toIso8601String(),
        },
        fromJson: (json) => response_models.AuthResponse.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        final authData = response.data!;
        _httpClient.setTokens(authData.accessToken, authData.refreshToken);
        return authData;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.AuthResponse?> guestLogin({
    required String deviceId,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/users/guest-login',
        data: {
          'deviceId': deviceId,
        },
        fromJson: (json) =>
            response_models.AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        final authData = response.data!;
        _httpClient.setTokens(authData.token, authData.token);
        return authData;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<void> logout() async {
    return ErrorHandler.safeApiCall(() async {
      await _httpClient.post('/auth/logout');
      _httpClient.clearTokens();
    });
  }

  Future<void> registerFcmToken({
    required String token,
    required String platform,
    required String deviceInfo,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<void>(
        '/fcm/register',
        data: {
          'token': token,
          'platform': platform,
          'deviceInfo': deviceInfo,
        },
        fromJson: (_) => null,
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<response_models.AuthResponse?> refreshToken() async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/auth/refresh',
        fromJson: (json) => response_models.AuthResponse.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        final authData = response.data!;
        _httpClient.setTokens(authData.accessToken, authData.refreshToken);
        return authData;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  // User endpoints
  Future<ApiUser?> getCurrentUser() async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<ApiUser>(
        '/users/me',
        fromJson: (json) => ApiUser.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<ApiUser?> getUserById(String userId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<ApiUser>(
        '/users/$userId',
        fromJson: (json) => ApiUser.fromJson((json as Map<String, dynamic>)['user']),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<ApiUser?> updateUserProfile({
    String? displayName,
    String? bio,
    String? gender,
    DateTime? dateOfBirth,
    String? profileImageUrl,
    String? bannerImageUrl,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final data = <String, dynamic>{};
      if (displayName != null) data['displayName'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (gender != null) data['gender'] = gender;
      if (dateOfBirth != null) data['dateOfBirth'] = dateOfBirth.toIso8601String();
      data['profileImageUrl'] = profileImageUrl;
      data['bannerImageUrl'] = bannerImageUrl;

      final response = await _httpClient.put<ApiUser>(
        '/users/profile',
        data: data,
        fromJson: (json) => ApiUser.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<String?> uploadUserAvatar(String filePath) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.uploadFile<Map<String, dynamic>>(
        endpoint: '/users/me/avatar',
        filePath: filePath,
        fieldName: 'avatar',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success && response.data != null) {
        return response.data!['url'] as String;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiUser>?> searchUsers({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/users/search',
        queryParameters: {
          'query': query,
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videoJson = (json as Map<String, dynamic>)['users'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videoJson},
                (item) => ApiUser.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  // Video endpoints
  Future<response_models.PaginatedResponse<ApiVideo>?> getVideos({
    int page = 1,
    int limit = 30,
    String? category,
    String? userId,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (category != null) queryParams['category'] = category;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/feed',
        queryParameters: queryParams,
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['videos'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiVideo>?> getPostedVideos({
    required String? userId,
    int page = 1,
    int limit = 30,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/user/$userId',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final postedVideosJson = (json as Map<String, dynamic>)['videos'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': postedVideosJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }


  Future<ApiVideo?> getVideoById(String videoId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<ApiVideo>(
        '/videos/$videoId',
        fromJson: (json) => ApiVideo.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<ApiVideo?> uploadVideo({
    required String videoPath,
    required String thumbnailPath,
    required double duration,
    required String title,
    required String description,
    // required String category,
    List<String>? tags,
    bool isPublic = true,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final body = {
        'title': title,
        'description': description,
        // 'category': category,
        'videoUrl': videoPath,
        'thumbnailUrl': thumbnailPath,
        'duration': duration,
        'tags': tags ?? [],
        'isPublic': isPublic,
      };

      final response = await _httpClient.post<ApiVideo>(
        '/videos',
        data: body,
        fromJson: (json) {
          final data = json;
          if (data == null || data is! Map<String, dynamic>) {
            throw Exception('No video data returned from API');
          }
          return ApiVideo.fromJson(data);
        },
      );

      if (response.success) {
        if (response.data != null) return response.data!;
        throw response_models.ApiException('No video data returned');
      }

      throw response_models.ApiException(response.message);
    });
  }


  Future<ApiCommonFile?> uploadCommonFile({
    required String videoPath,
    String type = "post",
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.uploadFile<ApiCommonFile>(
        endpoint: '/common/upload',
        filePath: videoPath,
        fieldName: 'file',
        fromJson: (json) => ApiCommonFile.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<void> deleteVideo(String videoId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/videos/$videoId');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<response_models.PaginatedResponse<ApiVideo>?> searchVideos({
    required String query,
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final queryParams = <String, dynamic>{
        'query': query,
        'page': page,
        'limit': limit,
      };
      
      if (category != null) queryParams['category'] = category;
      
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/search',
        queryParameters: queryParams,
        fromJson: (json) {
          final videoJson = (json as Map<String, dynamic>)['videos'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videoJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiVideo>?> getUserLikedVideos({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/liked/$userId',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videoJson = (json as Map<String, dynamic>)['videos'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videoJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
          );
        },
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  // Like endpoints
  Future<void> toggleLike({
    required String targetId,
    required String targetType,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      print('Toggling like for $targetType with ID: $targetId');
      final response = await _httpClient.post(
        '/likes/toggle',
        data: {
          'targetId': targetId,
          'targetType': targetType,
        },
      );
      
      if (!response.success) {
        print('Error toggling like: ${response.message}');
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<bool> checkIfLiked({
    required String targetId,
    required String targetType,
  }) async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/likes/status/$targetType/$targetId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['liked'] as bool? ?? false;
      }

      return false;
    });

    return result ?? false;
  }


  // Comment endpoints
  Future<response_models.PaginatedResponse<ApiComment>?> getComments({
    required String videoId,
    int page = 1,
    int limit = 20,
    String? parentCommentId,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (parentCommentId != null) {
        queryParams['parentCommentId'] = parentCommentId;
      }

      final response = await _httpClient.get<response_models.PaginatedResponse<ApiComment>>(
        '/comments/video/$videoId',
        queryParameters: queryParams,
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['comments'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiComment.fromJson(item as Map<String, dynamic>),
          );
        },
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }




  Future<ApiComment?> createComment({
    required String videoId,
    required String text,
    String? parentCommentId,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final data = {
        'videoId': videoId,
        'text': text,
      };

      if (parentCommentId != null) {
        data['parentCommentId'] = parentCommentId; // only include if not null
      }

      final response = await _httpClient.post<ApiComment>(
        '/comments',
        data: data,
        fromJson: (json) => ApiComment.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }


  Future<void> deleteComment(String commentId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/comments/$commentId');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  // Follow endpoints
  Future<void> toggleFollow(String userId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/follows/toggle',
        data: {
          'userId': userId,
        },
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> trackVideoView({
    required String videoId,
    required int watchTime,
    required double watchPercentage,
    required String sessionId,
    required String country,
    required String region,
    required String city, double? longitude, double? latitude,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final body = {
        "videoId": videoId,
        "watchTime": watchTime,
        "watchPercentage": watchPercentage,
        "sessionId": sessionId,
        "location": {
          "country": country,
          "region": region,
          "city": city,
          "lng": longitude,
          "lat": latitude
        }
      };

      final response = await _httpClient.post<Map<String, dynamic>>(
        '/analytics/track-view',
        data: body,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }



  Future<bool> checkIfFollowing(String userId) async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/follows/$userId/status',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['following'] as bool? ?? false;
      }

      return false;
    });

    return result ?? false;
  }

  Future<response_models.PaginatedResponse<ApiUser>?> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/follows/$userId/followers',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final followerJson = (json as Map<String, dynamic>)['followers'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': followerJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiUser.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiUser>?> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/follows/$userId/following',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['following'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiUser.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  // Chat endpoints (REST API for getting conversations)
  Future<response_models.PaginatedResponse<Conversation>?> getConversations({
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Conversation>>(
        '/chat/conversations',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) => response_models.PaginatedResponse.fromJson(
          json as Map<String, dynamic>,
          (item) => Conversation.fromJson(item as Map<String, dynamic>),
        ),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<Message>?> getSyncChatMessages({
    required DateTime date,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Message>>(
        '/chat/messages/sync',
        queryParameters: {
          // Encode ISO8601 string for URL
          'date': date,
        },
        fromJson: (json) {
          final messageJson = (json as Map<String, dynamic>)['messages'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': messageJson},
                (item) => Message.fromJson(item as Map<String, dynamic>),
          );
        },
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<Conversation?> createConversation({
    required List<String> participants,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<Conversation>(
        '/chat/conversations',
        data: {
          'participants': participants,
        },
        fromJson: (json) => Conversation.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  // Additional chat methods
  Future<response_models.PaginatedResponse<Message>?> getConversationMessages({
    required String conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Message>>(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) => response_models.PaginatedResponse.fromJson(
          json as Map<String, dynamic>,
          (item) => Message.fromJson(item as Map<String, dynamic>),
        ),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<Message?> sendMessage({
    required String conversationId,
    required String content,
    required String messageType,
    String? mediaUrl,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<Message>(
        '/chat/conversations/$conversationId/messages',
        data: {
          'content': content,
          'message_type': messageType,
          'media_url': mediaUrl,
        },
        fromJson: (json) => Message.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/chat/conversations/$conversationId/read',
        data: {
          'message_ids': messageIds,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> deleteMessage(String messageId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/chat/messages/$messageId');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> deleteChatConversation(String id) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/chat/conversations/$id');

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<Conversation?> getConversation(String conversationId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Conversation>(
        '/chat/conversations/$conversationId',
        fromJson: (json) => Conversation.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<ApiUser?> getUserProfile(String userId) async {
    return getUserById(userId);  // Use existing method
  }

  Future<response_models.PaginatedResponse<Conversation>?> getUserConversations({
    int page = 1,
    int limit = 20,
  }) async {
    return getConversations(page: page, limit: limit);  // Use existing method
  }

  // Block system methods
  Future<void> blockUser(
      String checkedId,
  ) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/blocks/toggle',
        data: {
          'userId': checkedId,
        },
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> unblockUser(
     String checkedId
  ) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post('/blocks/toggle',
        data: {
          'userId': checkedId,
        },
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<bool> isUserBlocked({
    required String checkerId,
    required String checkedId,
  }) async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/blocks/$checkedId/status',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['blocked'] as bool? ?? false;
      }

      return false;
    });

    return result ?? false;
  }


  Future<response_models.PaginatedResponse<ApiUser>?> getBlockedUsers({
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/blocks',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final blockUserJson = (json as Map<String, dynamic>)['blockedUsers'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': blockUserJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => ApiUser.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  // Follow system helper methods
  Future<void> followUser({
    required String followedId,
  }) async {
    return toggleFollow(followedId);  // Use existing method
  }

  Future<void> unfollowUser({
    required String followedId,
  }) async {
    return toggleFollow(followedId);  // Use existing method
  }

  Future<bool> isFollowing({
    required String followedId,
  }) async {
    return checkIfFollowing(followedId);
  }

  Future<response_models.PaginatedResponse<ApiUser>?> getUserFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return getFollowers(userId: userId, page: page, limit: limit);  // Use existing method
  }

  Future<response_models.PaginatedResponse<ApiUser>?> getUserFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    return getFollowing(userId: userId, page: page, limit: limit);  // Use existing method
  }

  // Report system methods
  Future<Report?> createReport({
    required String reportType,
    required String targetId,
    required String targetType,
    required String reason,
    String? description,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<Report>(
        '/reports',
        data: {
         // 'report_type': reportType,
          'targetId': targetId,
          'targetType': targetType,
          'reason': reason,
          'description': description ?? '',
        },
        fromJson: (json) => Report.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<Report>?> getUserReports({
    int page = 1,
    int limit = 30,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Report>>(
        '/reports/user',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final reportJson = (json as Map<String, dynamic>)['reports'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': reportJson}, // wrap in 'data' to match your PaginatedResponse
                (item) => Report.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<Report?> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.put<Report>(
        '/reports/$reportId/status',
        data: {
          'status': status,
        },
        fromJson: (json) => Report.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<void> deleteReport(String reportId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/reports/$reportId');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  // Search and discovery methods
  Future<response_models.PaginatedResponse<ApiVideo>?> getTrendingVideos({
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/trending',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['videos'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson},
                (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiUser>?> getPopularUsers({
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/users/popular',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['users'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson},
                (item) => ApiUser.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<ApiVideo>?> getVideosByCategory({
    required String category,
    int page = 1,
    int limit = 20,
  }) async {
    return getVideos(category: category, page: page, limit: limit);  // Use existing method
  }

  Future<response_models.PaginatedResponse<ApiVideo>?> getVideosByTag({
    required String tag,
    int page = 1,
    int limit = 20,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiVideo>>(
        '/videos/tags/$tag',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) => response_models.PaginatedResponse.fromJson(
          json as Map<String, dynamic>,
          (item) => ApiVideo.fromJson(item as Map<String, dynamic>),
        ),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<List<String>> getRecentSearches() async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/search/recent',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success && response.data != null) {
        return (response.data!['searches'] as List<dynamic>?)
            ?.cast<String>() ?? <String>[];
      }
      
      return <String>[];
    });
    
    return result ?? <String>[];
  }

  Future<void> saveSearchQuery(String query) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/search/save',
        data: {
          'query': query,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> clearSearchHistory() async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/search/history');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  // Notification methods
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, String>? data,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/notifications/send',
        data: {
          'user_id': userId,
          'title': title,
          'body': body,
          'image_url': imageUrl,
          'data': data,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> deactivateFcmToken({
    required String token,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<void>(
        '/fcm/deactivate',
        data: {
          'token': token,
        },
        fromJson: (_) => null,
      );

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> subscribeToNotificationTopic(String topic) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/notifications/topics/subscribe',
        data: {
          'topic': topic,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> unsubscribeFromNotificationTopic(String topic) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/notifications/topics/unsubscribe',
        data: {
          'topic': topic,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> saveNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, String>? data,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/notifications/save',
        data: {
          'title': title,
          'body': body,
          'image_url': imageUrl,
          'data': data,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<response_models.AuthResponse?> googleLogin({
    required String token,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/users/google-login',
        data: {
          'token': token,
        },
        fromJson: (json) => response_models.AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        final authData = response.data!;
        _httpClient.setTokens(authData.token, authData.token);
        return authData;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.AuthResponse?> appleLogin({
    required String token,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<response_models.AuthResponse>(
        '/users/apple-login',
        data: {
          'token': token,
        },
        fromJson: (json) => response_models.AuthResponse.fromJson(
          json as Map<String, dynamic>,
        ),
      );

      if (response.success && response.data != null) {
        final authData = response.data!;
        _httpClient.setTokens(authData.token, authData.token);
        return authData;
      }

      throw response_models.ApiException(response.message);
    });
  }

  // Meet/Online user methods
  Future<void> joinMeet() async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/chat/meet/join',
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> leaveMeet() async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post(
        '/chat/meet/leave',
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<List<ApiUser>> getOnlineUsers() async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<ApiUser>>(
        '/users/online',
        fromJson: (json) => response_models.PaginatedResponse.fromJson(
          json as Map<String, dynamic>,
          (item) => ApiUser.fromJson(item as Map<String, dynamic>),
        ),
      );
      
      if (response.success && response.data != null) {
        return response.data!.data;
      }
      
      return <ApiUser>[];
    });
    
    return result ?? <ApiUser>[];
  }

  Future<bool> getOnlineUserStatus() async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/chat/meet/status',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final data = response.data!['data'] as Map<String, dynamic>?;
        return data?['isInMeet'] as bool? ?? false;
      }
      return false;
    });

    return result ?? false;
  }

  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    String? city,
    String? country,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.put(
        '/users/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (city != null) 'city': city,
          if (country != null) 'country': country,
        },
      );

      // 🔍 Debug print the full response
      print('Update location response: ${response.toJson()}');

      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  // Chat and messaging methods  
  Future<String> createOrGetConversation({
    required String userId1,
    required String userId2,
  }) async {
    final result = await ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '/chat/conversations',
        data: {
          'user_ids': [userId1, userId2],
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success && response.data != null) {
        return response.data!['conversation_id'] as String? ?? '';
      }
      
      throw response_models.ApiException(response.message);
    });
    
    return result ?? '';
  }

  Future<Message?> sendChatMessage({
    required String conversationId,
    required String content,
    required String messageType,
    String? mediaUrl,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.post<Message>(
        '/chat/messages',
        data: {
          'conversation_id': conversationId,
          'content': content,
          'message_type': messageType,
          'media_url': mediaUrl,
        },
        fromJson: (json) => Message.fromJson(json as Map<String, dynamic>),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<Message>?> getChatMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Message>>(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) => response_models.PaginatedResponse.fromJson(
          json as Map<String, dynamic>,
          (item) => Message.fromJson(item as Map<String, dynamic>),
        ),
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.PaginatedResponse<Conversation>?> getChatConversations({
    int page = 1,
    int limit = 500,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.get<response_models.PaginatedResponse<Conversation>>(
        '/chat/conversations',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        fromJson: (json) {
          final videosJson = (json as Map<String, dynamic>)['conversations'] as List<dynamic>? ?? [];
          return response_models.PaginatedResponse.fromJson(
            {'data': videosJson},
                (item) => Conversation.fromJson(item as Map<String, dynamic>),
          );
        },
      );
      
      if (response.success && response.data != null) {
        return response.data!;
      }
      
      throw response_models.ApiException(response.message);
    });
  }

  Future<void> markChatMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.put(
        '/chat/conversations/$conversationId/seen',
        data: {
          'message_ids': messageIds,
        },
      );
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<void> deleteChatMessage(String messageId) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.delete('/chat/messages/$messageId');
      
      if (!response.success) {
        throw response_models.ApiException(response.message);
      }
    });
  }

  Future<ApiCommonFile?> uploadCommonImageFile({
    required String imagePath,
    String type = "post",
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final response = await _httpClient.uploadFile<ApiCommonFile>(
        endpoint: '/common/upload',
        filePath: imagePath,
        fieldName: 'file',
        additionalData: {
          'type': type,
        },
        fromJson: (json) => ApiCommonFile.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }

  Future<response_models.NearbyUsersResponse?> getNearbyUsers({
    required String genderFilter,
    int? minAge,
    int? maxAge,
    int? maxDistance,
  }) async {
    return ErrorHandler.safeApiCall(() async {
      final queryParams = <String, dynamic>{
        'genderFilter': genderFilter,
        if (minAge != null) 'minAge': minAge,
        if (maxAge != null) 'maxAge': maxAge,
        if (maxDistance != null) 'maxDistance': maxDistance,
      };

      final response = await _httpClient.get<response_models.NearbyUsersResponse>(
        '/chat/meet/nearby',
        queryParameters: queryParams,
        fromJson: (json) => response_models.NearbyUsersResponse.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        return response.data!;
      }

      throw response_models.ApiException(response.message);
    });
  }




}