import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/services/video_service.dart';
import 'package:vidstream/services/comment_service.dart';
import 'package:vidstream/services/like_service.dart';
import 'package:vidstream/services/follow_service.dart';
import 'package:vidstream/services/report_service.dart';
import 'package:vidstream/services/block_service.dart';
import 'package:vidstream/services/search_service.dart';
import 'package:vidstream/services/api_service.dart';
import 'package:vidstream/services/chat_service.dart';

class ApiRepository {
  static final ApiRepository _instance = ApiRepository._internal();
  factory ApiRepository() => _instance;
  ApiRepository._internal();
  
  static ApiRepository get instance => _instance;

  // Lazy initialization to prevent circular dependencies
  AuthService? _auth;
  VideoService? _videos;
  CommentService? _comments;
  LikeService? _likes;
  FollowService? _follows;
  ReportService? _reports;
  BlockService? _blocks;
  SearchService? _search;
  ApiService? _api;
  ChatService? _chat;

  // Getters with lazy initialization
  AuthService get auth => _auth ??= AuthService();
  VideoService get videos => _videos ??= VideoService();
  CommentService get comments => _comments ??= CommentService();
  LikeService get likes => _likes ??= LikeService();
  FollowService get follows => _follows ??= FollowService();
  ReportService get reports => _reports ??= ReportService();
  BlockService get blocks => _blocks ??= BlockService();
  SearchService get search => _search ??= SearchService();
  ApiService get api => _api ??= ApiService();
  ChatService get chat => _chat ??= ChatService();
  
  // Initialize all services (lightweight)
  Future<void> initialize() async {
    try {
      // Initialize core API service first
      await api.initialize();
      
      // Initialize authentication (can be done async)
      auth.initialize().catchError((e) => print('Auth init error: $e'));
      
      // Initialize chat service (can be done async)
      chat.initialize().catchError((e) => print('Chat init error: $e'));
      
      print('✅ ApiRepository initialized');
    } catch (e) {
      print('❌ ApiRepository init error: $e');
      // Don't throw - let app continue with limited functionality
    }
  }
  
  // Dispose all resources
  void dispose() {
    _auth?.dispose();
    _videos?.dispose();
    _chat?.dispose();
  }
}