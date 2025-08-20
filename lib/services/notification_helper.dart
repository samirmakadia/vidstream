import 'package:vidstream/services/notification_service.dart';

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();

  // Send notification when user gets a like on their video
  static Future<void> sendVideoLikeNotification({
    required String videoOwnerId,
    required String likerName,
    required String videoTitle,
    required String videoId,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: videoOwnerId,
      title: 'New Like! 👍',
      body: '$likerName liked your video "$videoTitle"',
      data: {
        'type': 'video_like',
        'videoId': videoId,
        'likerName': likerName,
      },
    );
  }

  // Send notification when user gets a comment on their video
  static Future<void> sendVideoCommentNotification({
    required String videoOwnerId,
    required String commenterName,
    required String videoTitle,
    required String videoId,
    required String commentText,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: videoOwnerId,
      title: 'New Comment! 💬',
      body: '$commenterName commented on "$videoTitle": ${commentText.length > 50 ? '${commentText.substring(0, 50)}...' : commentText}',
      data: {
        'type': 'video_comment',
        'videoId': videoId,
        'commenterName': commenterName,
      },
    );
  }

  // Send notification when user gets a new follower
  static Future<void> sendNewFollowerNotification({
    required String userId,
    required String followerName,
    required String followerId,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: userId,
      title: 'New Follower! 🎉',
      body: '$followerName started following you',
      data: {
        'type': 'follow',
        'userId': followerId,
        'followerName': followerName,
      },
    );
  }

  // Send notification when someone follows a user (alias for backward compatibility)
  static Future<void> sendFollowNotification({
    required String toUserId,
    required String fromUserId,
  }) async {
    // Get the follower's name - for now using userId as name
    await sendNewFollowerNotification(
      userId: toUserId,
      followerName: fromUserId,
      followerId: fromUserId,
    );
  }

  // Send notification for video post approval/rejection (if you have moderation)
  static Future<void> sendVideoModerationNotification({
    required String videoOwnerId,
    required String videoTitle,
    required bool isApproved,
    String? reason,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: videoOwnerId,
      title: isApproved ? 'Video Published! ✅' : 'Video Rejected ❌',
      body: isApproved 
          ? 'Your video "$videoTitle" is now live!'
          : 'Your video "$videoTitle" was rejected${reason != null ? ': $reason' : ''}',
      data: {
        'type': 'video_moderation',
        'isApproved': isApproved.toString(),
        'reason': reason ?? '',
      },
    );
  }

  // Send notification for app updates
  static Future<void> sendAppUpdateNotification({
    required String userId,
    required String version,
    required String releaseNotes,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: userId,
      title: 'VidStream Update Available! 🚀',
      body: 'Version $version is now available with exciting new features!',
      data: {
        'type': 'app_update',
        'version': version,
        'releaseNotes': releaseNotes,
      },
    );
  }

  // Send welcome notification to new users
  static Future<void> sendWelcomeNotification({
    required String userId,
    required String userName,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: userId,
      title: 'Welcome to VidStream! 🎬',
      body: 'Hi $userName! Start creating amazing videos and connect with the community.',
      data: {
        'type': 'welcome',
        'userName': userName,
      },
    );
  }

  // Send daily/weekly digest notifications
  static Future<void> sendDigestNotification({
    required String userId,
    required int newLikes,
    required int newFollowers,
    required int newComments,
  }) async {
    final List<String> highlights = [];
    
    if (newLikes > 0) highlights.add('$newLikes new likes');
    if (newFollowers > 0) highlights.add('$newFollowers new followers');
    if (newComments > 0) highlights.add('$newComments new comments');

    if (highlights.isNotEmpty) {
      await _notificationService.sendNotificationToUser(
        userId: userId,
        title: 'Your Weekly Highlights! ⭐',
        body: 'You received ${highlights.join(', ')} this week!',
        data: {
          'type': 'digest',
          'newLikes': newLikes.toString(),
          'newFollowers': newFollowers.toString(),
          'newComments': newComments.toString(),
        },
      );
    }
  }

  // Subscribe user to topic-based notifications
  static Future<void> subscribeToTopics(List<String> topics) async {
    for (final topic in topics) {
      await _notificationService.subscribeToTopic(topic);
    }
  }

  // Unsubscribe user from topic-based notifications
  static Future<void> unsubscribeFromTopics(List<String> topics) async {
    for (final topic in topics) {
      await _notificationService.unsubscribeFromTopic(topic);
    }
  }

  // Default topics users might want to subscribe to
  static const List<String> defaultTopics = [
    'general_announcements',
    'feature_updates',
    'community_highlights',
    'maintenance_alerts',
  ];

  // Subscribe new users to default topics
  static Future<void> subscribeToDefaultTopics() async {
    await subscribeToTopics(defaultTopics);
  }
}