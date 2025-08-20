import 'package:vidstream/repositories/api_repository.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/utils/auth_utils.dart';
import 'package:vidstream/services/follow_service.dart';
import 'package:vidstream/services/meet_service.dart';
import 'package:vidstream/services/chat_service.dart';

class DemoDataService {
  static Future<void> createSampleVideos() async {
    print('Auth status: ${AuthUtils.getAuthStatus()}');
    
    AuthUtils.requireAuthentication();
    final currentUserId = AuthUtils.getCurrentUserId()!;

    print('Creating sample videos for user: $currentUserId');
    try {
      // Create sample videos with demo data
      final sampleVideos = [
        ApiVideo(
          id: '',
          userId: currentUserId,
          title: 'Amazing Sunset Timelapse',
          description: 'Watch this beautiful sunset over the mountains! 🌅 Nature at its finest.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          thumbnailUrl: 'https://pixabay.com/get/g8c188c5f9ce209e44075914d5169aa822b788ffc0f0569f7eec8fd85bc4d1cf6346d6d408106a258bb69dd56ac8085316579096c621933eb711aa9420cdb34b5_1280.jpg',
          category: 'nature',
          tags: ['sunset', 'nature', 'inspiring'],
          likesCount: 42,
          viewsCount: 156,
          commentsCount: 8,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ApiVideo(
          id: '',
          userId: currentUserId,
          title: 'Funny Cat Compilation',
          description: 'These cats are hilarious! 😸 You will laugh out loud watching this.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          thumbnailUrl: 'https://pixabay.com/get/g4d738cff1b65fe601d5212777093371418e36f8cafa377166b493136eb14f205507a8d0c4af592c8939c055a05a10561ae58d484ab544f97ce11396448499af8_1280.jpg',
          category: 'entertainment',
          tags: ['funny', 'pets', 'comedy'],
          likesCount: 89,
          viewsCount: 342,
          commentsCount: 15,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ApiVideo(
          id: '',
          userId: currentUserId,
          title: 'How to Make Perfect Coffee',
          description: 'Learn the secrets of brewing the perfect cup of coffee ☕ Step by step tutorial.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
          thumbnailUrl: 'https://pixabay.com/get/g27116fd79bc37a869de38d85b1a111b5f20911d5b227c01ee0cee5d8465be679287f229c78e97fe72aacc7c0513a7489d40569922e1bc7a5878134cc1cedca88_1280.jpg',
          category: 'tutorial',
          tags: ['tutorial', 'cooking', 'lifestyle'],
          likesCount: 67,
          viewsCount: 234,
          commentsCount: 12,
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
        ApiVideo(
          id: '',
          userId: currentUserId,
          title: 'Dancing in the Rain',
          description: 'Sometimes you just have to dance! 💃 Rainy day vibes and good energy.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
          thumbnailUrl: 'https://pixabay.com/get/g1dc2556bc94c39167b9644bf298809574b98bce0dc23b34e1067fccdf76d03cf9b7c1cd33b5e905d841f73adf44d557b67c032cbfbd371c9430b7806dca44ecc_1280.jpg',
          category: 'lifestyle',
          tags: ['dance', 'emotional', 'inspiring'],
          likesCount: 123,
          viewsCount: 456,
          commentsCount: 23,
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        ApiVideo(
          id: '',
          userId: currentUserId,
          title: 'Epic Gaming Montage',
          description: 'Check out these incredible gaming moments! 🎮 Level up your skills.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
          thumbnailUrl: 'https://pixabay.com/get/gd95d28589e35082ee04aa3e513e7cdad7f0b60169631d26c6263531954ac85a7ad8893931d235738117ae58496d6a156cfa7d27777e4817546ba6b7a6bb45c1e_1280.jpg',
          category: 'gaming',
          tags: ['gaming', 'funny', 'tutorial'],
          likesCount: 98,
          viewsCount: 387,
          commentsCount: 19,
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];

      // Create the videos in Firestore and collect their IDs
      List<String> createdVideoIds = [];
      for (final video in sampleVideos) {
        final createdVideo = await ApiRepository.instance.videos.createVideo(
          title: video.title,
          description: video.description,
          category: video.category,
          tags: video.tags,
          isPublic: true,
        );
        if (createdVideo != null) {
          createdVideoIds.add(createdVideo.id);
        }
      }

      // Create some sample likes for the first few videos to demonstrate liked videos
      if (createdVideoIds.isNotEmpty) {
        final videosToLike = createdVideoIds.take(3).toList(); // Like first 3 videos
        
        for (final videoId in videosToLike) {
          try {
            await ApiRepository.instance.likes.toggleLike(
              userId: currentUserId,
              targetId: videoId,
              targetType: 'video',
            );
            print('Liked video: $videoId');
          } catch (e) {
            print('Failed to like video $videoId: $e');
          }
        }
      }

      print('Sample videos and likes created successfully!');
    } catch (e) {
      print('Failed to create sample videos: $e');
    }
  }

  // Method to create sample likes for existing videos
  static Future<void> createSampleLikes() async {
    print('Auth status: ${AuthUtils.getAuthStatus()}');
    
    AuthUtils.requireAuthentication();
    final currentUserId = AuthUtils.getCurrentUserId()!;

    print('Creating sample likes for user: $currentUserId');
    try {
      // Get some existing videos to like
      final videos = await ApiRepository.instance.videos.getVideosOnce(limit: 5);
      
      if (videos.isNotEmpty) {
        for (final video in videos.take(3)) { // Like first 3 videos
          try {
            await ApiRepository.instance.likes.toggleLike(
              userId: currentUserId,
              targetId: video.id,
              targetType: 'video',
            );
            print('Liked existing video: ${video.id}');
          } catch (e) {
            print('Failed to like existing video ${video.id}: $e');
          }
        }
        print('Sample likes created successfully!');
      } else {
        print('No videos found to like');
      }
    } catch (e) {
      print('Failed to create sample likes: $e');
    }
  }

  // Method to create sample follow relationships
  static Future<void> createSampleFollows() async {
    print('Auth status: ${AuthUtils.getAuthStatus()}');
    
    AuthUtils.requireAuthentication();
    final currentUserId = AuthUtils.getCurrentUserId()!;

    print('Creating sample follows for user: $currentUserId');
    try {
      final followService = FollowService();
      
      // Create some sample users first (we'll simulate them as documents)
      final sampleUsers = [
        ApiUser(
          id: 'demo_user_1',
          email: 'demo1@example.com',
          displayName: 'Alice Johnson',
          bio: 'Nature lover and photographer 📸 Capturing beautiful moments every day.',
          profileImageUrl: 'https://pixabay.com/get/g4d738cff1b65fe601d5212777093371418e36f8cafa377166b493136eb14f205507a8d0c4af592c8939c055a05a10561ae58d484ab544f97ce11396448499af8_1280.jpg',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now().subtract(const Duration(days: 30)),
          isGuest: false,
        ),
        ApiUser(
          id: 'demo_user_2',
          email: 'demo2@example.com',
          displayName: 'Mike Chen',
          bio: 'Tech enthusiast 💻 Sharing coding tips and tutorials for everyone.',
          profileImageUrl: 'https://pixabay.com/get/g27116fd79bc37a869de38d85b1a111b5f20911d5b227c01ee0cee5d8465be679287f229c78e97fe72aacc7c0513a7489d40569922e1bc7a5878134cc1cedca88_1280.jpg',
          createdAt: DateTime.now().subtract(const Duration(days: 25)),
          updatedAt: DateTime.now().subtract(const Duration(days: 25)),
          isGuest: false,
        ),
        ApiUser(
          id: 'demo_user_3',
          email: 'demo3@example.com',
          displayName: 'Sarah Williams',
          bio: 'Fitness coach 💪 Helping you achieve your health goals step by step.',
          profileImageUrl: 'https://pixabay.com/get/g1dc2556bc94c39167b9644bf298809574b98bce0dc23b34e1067fccdf76d03cf9b7c1cd33b5e905d841f73adf44d557b67c032cbfbd371c9430b7806dca44ecc_1280.jpg',
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          updatedAt: DateTime.now().subtract(const Duration(days: 20)),
          isGuest: false,
        ),
        ApiUser(
          id: 'demo_user_4',
          email: 'demo4@example.com',
          displayName: 'David Lopez',
          bio: 'Music producer 🎵 Creating beats and sharing the creative process.',
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          updatedAt: DateTime.now().subtract(const Duration(days: 15)),
          isGuest: false,
        ),
      ];

      // Create these sample users in Firestore
      for (final user in sampleUsers) {
        try {
          //await FirebaseRepository.instance.users.doc(user.id).set(user.toJson());
          print('Created sample user: ${user.displayName}');
        } catch (e) {
          print('Failed to create sample user ${user.displayName}: $e');
        }
      }

      // Create follow relationships
      // Current user follows some sample users
      for (int i = 0; i < 3; i++) {
        try {
          await followService.toggleFollow(
            followerId: currentUserId,
            followedId: sampleUsers[i].id,
          );
          print('Current user now follows: ${sampleUsers[i].displayName}');
        } catch (e) {
          print('Failed to create follow relationship with ${sampleUsers[i].displayName}: $e');
        }
      }

      // Some sample users follow the current user
      for (int i = 1; i < 4; i++) {
        try {
          await followService.toggleFollow(
            followerId: sampleUsers[i].id,
            followedId: currentUserId,
          );
          print('${sampleUsers[i].displayName} now follows current user');
        } catch (e) {
          print('Failed to create follower relationship with ${sampleUsers[i].displayName}: $e');
        }
      }

      print('Sample follow relationships created successfully!');
    } catch (e) {
      print('Failed to create sample follows: $e');
    }
  }

  // Method to create sample online users for Meet
  static Future<void> createSampleOnlineUsers() async {
    print('Auth status: ${AuthUtils.getAuthStatus()}');
    
    AuthUtils.requireAuthentication();
    final currentUserId = AuthUtils.getCurrentUserId()!;

    print('Creating sample online users for Meet feature');
    try {
      final meetService = MeetService();
      
      // Create sample online users
      final sampleOnlineUsers = [
        OnlineUser(
          userId: 'demo_online_1',
          lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
          isInMeet: true,
          latitude: 37.7749,
          longitude: -122.4194,
        ),
        OnlineUser(
          userId: 'demo_online_2',
          lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
          isInMeet: true,
          latitude: 37.7849,
          longitude: -122.4094,
        ),
        OnlineUser(
          userId: 'demo_online_3',
          lastSeen: DateTime.now().subtract(const Duration(minutes: 3)),
          isInMeet: true,
          latitude: 37.7649,
          longitude: -122.4294,
        ),
        OnlineUser(
          userId: 'demo_online_4',
          lastSeen: DateTime.now().subtract(const Duration(minutes: 7)),
          isInMeet: false,
          latitude: 37.7549,
          longitude: -122.4394,
        ),
      ];

      // Create these online users in Firestore
      for (final user in sampleOnlineUsers) {
        try {
          // TODO: Replace with API call
          // await ApiRepository.instance.users.createOnlineUser(user);
          print('Created sample online user: ${user.userId}');
        } catch (e) {
          print('Failed to create sample online user ${user.userId}: $e');
        }
      }

      print('Sample online users created successfully!');
    } catch (e) {
      print('Failed to create sample online users: $e');
    }
  }

  // Method to create sample chat conversations
  static Future<void> createSampleChatData() async {
    print('Auth status: ${AuthUtils.getAuthStatus()}');
    
    AuthUtils.requireAuthentication();
    final currentUserId = AuthUtils.getCurrentUserId()!;

    print('Creating sample chat data');
    try {
      final chatService = ChatService(
        connectivityService: null,
        httpClient: null,
      );
      
      // Create sample users first (for chat)
      final sampleUsers = [
        'demo_online_1',
        'demo_online_2',
        'demo_online_3',
      ];

      for (final otherUserId in sampleUsers) {
        try {
          // Create conversation
          final conversationId = await chatService.getOrCreateConversation(otherUserId);

          // Send sample messages
          await chatService.sendMessage(
            conversationId: conversationId,
            messageType: 'text',
            content: {'text': 'Hey! How are you doing?'},
          );

          await Future.delayed(const Duration(seconds: 1));

          await chatService.sendMessage(
            conversationId: conversationId,
            messageType: 'text',
            content: {'text': 'Hi! I\'m doing great, thanks for asking!'},
          );

          await Future.delayed(const Duration(seconds: 1));

          await chatService.sendMessage(
            conversationId: conversationId,
            messageType: 'text',
            content: {'text': 'That\'s awesome! Want to chat more?'},
          );

          print('Created sample conversation with user: $otherUserId');
        } catch (e) {
          print('Failed to create sample conversation with $otherUserId: $e');
        }
      }

      print('Sample chat data created successfully!');
    } catch (e) {
      print('Failed to create sample chat data: $e');
    }
  }
}