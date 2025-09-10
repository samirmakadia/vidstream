// API Data Models for VidMeet App (adapted for REST API)

// User Model - adapted for API
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ApiUser {
  final String id;
  final String userId; // new field
  final String email;
  final String displayName;
  final String? username;
  final String? profileImageUrl;
  final String? photoURL;
  final String? bannerImageUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final String? gender;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> following;
  final List<String> followers;
  final int followersCount;
  final int followingCount;
  final int videosCount;
  final bool isVerified;
  final bool isGuest;
  final bool isInMeet;
  final bool isFollow;
  final int age;
  final double distance;
  final bool isOnline;

  String get uid => id;

  ApiUser({
    required this.id,
    required this.userId,
    required this.email,
    required this.displayName,
    this.username,
    this.profileImageUrl,
    this.photoURL,
    this.bannerImageUrl,
    this.bio,
    required this.isFollow,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
    required this.updatedAt,
    this.following = const [],
    this.followers = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.videosCount = 0,
    this.isVerified = false,
    this.isGuest = false,
    this.isInMeet = false,
    this.age = 20,
    this.distance = 0.0,
    this.isOnline = false,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      username: json['username'],
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      photoURL: json['photo_url'] ?? json['photoURL'],
      bannerImageUrl: json['banner_image_url'] ?? json['bannerImageUrl'],
      bio: json['bio'],
      dateOfBirth: json['date_of_birth'] != null || json['dateOfBirth'] != null
          ? DateTime.tryParse(json['date_of_birth'] ?? json['dateOfBirth'])
          : null,
      gender: json['gender'],
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ?? DateTime.now(),
      following: List<String>.from(json['following'] ?? []),
      followers: List<String>.from(json['followers'] ?? []),
      followersCount: json['followerCount'] ?? json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      videosCount: json['videos_count'] ?? json['videoCount'] ?? json['videosCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
      isGuest: json['is_guest'] ?? json['isGuest'] ?? false,
      isFollow: json['isFollow'] ?? false,
      isInMeet: json['is_in_meet'] ?? json['isInMeet'] ?? false,
      age: json['age'] ?? 20,
      distance: (json['distance'] != null) ? (json['distance'] as num).toDouble() : 0.0,
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'userId': userId,
      'email': email,
      'display_name': displayName,
      'username': username,
      'profile_image_url': profileImageUrl,
      'photo_url': photoURL,
      'banner_image_url': bannerImageUrl,
      'bio': bio,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'following': following,
      'followers': followers,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'videos_count': videosCount,
      'isVerified': isVerified,
      'is_guest': isGuest,
      'isFollow': isFollow,
      'is_in_meet': isInMeet,
      'age': age,
      'distance': distance,
      'isOnline': isOnline,
    };
  }

  ApiUser copyWith({
    String? id,
    String? userId,
    String? email,
    String? displayName,
    String? username,
    String? profileImageUrl,
    String? photoURL,
    String? bannerImageUrl,
    String? bio,
    DateTime? dateOfBirth,
    String? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? following,
    List<String>? followers,
    int? followersCount,
    int? followingCount,
    int? videosCount,
    bool? isVerified,
    bool? isGuest,
    bool? isFollow,
    bool? isInMeet,
    int? age,
    double? distance,
    bool? isOnline,
  }) {
    return ApiUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      photoURL: photoURL ?? this.photoURL,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      bio: bio ?? this.bio,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      videosCount: videosCount ?? this.videosCount,
      isVerified: isVerified ?? this.isVerified,
      isGuest: isGuest ?? this.isGuest,
      isFollow: isFollow ?? this.isFollow,
      isInMeet: isInMeet ?? this.isInMeet,
      age: age ?? this.age,
      distance: distance ?? this.distance,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

// Video Model - adapted for API
class ApiVideo {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String category;
  final List<String> tags;
  final int likesCount;
  final int viewsCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  late final bool isLiked;
  final ApiUser? user;

  ApiVideo({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.category,
    this.tags = const [],
    this.likesCount = 0,
    this.viewsCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
    this.isLiked = false,
    this.user,
  });

  factory ApiVideo.fromJson(Map<String, dynamic> json) {
    return ApiVideo(
      id: json['_id'] ?? '', // match API "_id"
      userId: json['userId']?['_id'] ?? '', // nested userId object
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'] ?? json['video_url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail_url'] ?? '',
      category: json['category'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      viewsCount: json['viewsCount'] ?? json['views_count'] ?? 0,
      commentsCount: json['commentsCount'] ?? json['comments_count'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now(),
      isPublic: json['isPublic'] ?? json['is_public'] ?? true,
      isLiked: json['isLiked'] ?? json['is_liked'] ?? false,
      user: json['userId'] != null ? ApiUser.fromJson(json['userId']) : null, // optional user
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'category': category,
      'tags': tags,
      'likes_count': likesCount,
      'views_count': viewsCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_public': isPublic,
      'is_liked': isLiked,
      if (user != null) 'user': user!.toJson(),
    };
  }

  ApiVideo copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    String? category,
    List<String>? tags,
    int? likesCount,
    int? viewsCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    bool? isLiked,
    ApiUser? user,
  }) {
    return ApiVideo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      isLiked: isLiked ?? this.isLiked,
      user: user ?? this.user,
    );
  }
}

class ApiCommonFile {
  final String url;
  final String thumbnailUrl;
  final String filename;
  final String originalName;
  final int size;
  final double duration;
  final Dimensions dimensions;
  final String fileType;
  final String category;

  ApiCommonFile({
    required this.url,
    required this.thumbnailUrl,
    required this.filename,
    required this.originalName,
    required this.size,
    required this.duration,
    required this.dimensions,
    required this.fileType,
    required this.category,
  });

  factory ApiCommonFile.fromJson(Map<String, dynamic> json) {
    return ApiCommonFile(
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail'] ?? '',
      filename: json['filename'] ?? '',
      originalName: json['originalName'] ?? '',
      size: json['size'] ?? 0,
      duration: (json['duration'] != null) ? (json['duration'] as num).toDouble() : 0.0,
      dimensions: json['dimensions'] != null
          ? Dimensions.fromJson(json['dimensions'])
          : Dimensions(width: 0, height: 0),
      fileType: json['fileType'] ?? '',
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'filename': filename,
      'originalName': originalName,
      'size': size,
      'duration': duration,
      'dimensions': dimensions.toJson(),
      'fileType': fileType,
      'category': category,
    };
  }

  ApiCommonFile copyWith({
    String? url,
    String? thumbnailUrl,
    String? filename,
    String? originalName,
    int? size,
    double? duration,
    Dimensions? dimensions,
    String? fileType,
    String? category,
  }) {
    return ApiCommonFile(
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      filename: filename ?? this.filename,
      originalName: originalName ?? this.originalName,
      size: size ?? this.size,
      duration: duration ?? this.duration,
      dimensions: dimensions ?? this.dimensions,
      fileType: fileType ?? this.fileType,
      category: category ?? this.category,
    );
  }
}

class Dimensions {
  final int width;
  final int height;

  Dimensions({
    required this.width,
    required this.height,
  });

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
    };
  }
}

// Comment Model - adapted for API
class ApiComment {
  final String id;
  final String videoId;
  final String text;
  int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentCommentId;
  final ApiUser? user;
  final List<ApiComment>? replies;
  final int? v;
  bool isLiked; // Changed from nullable to non-nullable with default false

  ApiComment({
    required this.id,
    required this.videoId,
    required this.text,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    this.user,
    this.replies,
    this.v,
    this.isLiked = false, // Default value
  });

  factory ApiComment.fromJson(Map<String, dynamic> json) {
    return ApiComment(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      videoId: json['videoId']?.toString() ?? json['video_id']?.toString() ?? '',
      text: json['text'] ?? '',
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ?? DateTime.now(),
      parentCommentId: json['parentCommentId']?.toString() ?? json['parent_comment_id']?.toString(),
      user: json['userId'] != null
          ? ApiUser.fromJson(json['userId'] as Map<String, dynamic>)
          : (json['user'] != null ? ApiUser.fromJson(json['user']) : null),
      replies: json['replies'] != null
          ? List<ApiComment>.from((json['replies'] as List).map((x) => ApiComment.fromJson(x)))
          : null,
      v: json['__v'],
      isLiked: json['isLiked'] ?? false, // Handle like status
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'text': text,
      'likesCount': likesCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'parentCommentId': parentCommentId,
      if (user != null) 'user': user!.toJson(),
      if (replies != null) 'replies': replies!.map((x) => x.toJson()).toList(),
      if (v != null) '__v': v,
      'isLiked': isLiked, // Include like status in JSON
    };
  }
}

// Like Model - adapted for API
class ApiLike {
  final String id;
  final String userId;
  final String targetId;
  final String targetType;
  final DateTime createdAt;

  ApiLike({
    required this.id,
    required this.userId,
    required this.targetId,
    required this.targetType,
    required this.createdAt,
  });

  factory ApiLike.fromJson(Map<String, dynamic> json) {
    return ApiLike(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? json['targetId']?.toString() ?? '',
      targetType: json['target_type'] ?? json['targetType'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'target_id': targetId,
      'target_type': targetType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Message Model for Socket.IO chat
enum MessageStatus {
  sent,
  delivered,
  read,
  pending,
}

class MessageModel {
  final String? id;
  final String messageId;
  final String conversationId;
  final String senderId;
  final String? receiverId;
  final String messageType;
  final MessageContent content;
  final MessageStatus status;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final List<String> deletedFor;

  String get message => content.text ?? '';

  DateTime get sentAt => DateTime.tryParse(createdAt) ?? DateTime.now();
  DateTime get updatedAtDate => DateTime.tryParse(updatedAt) ?? DateTime.now();

  bool get isRead => status == MessageStatus.read;
  bool get isDelivered => status == MessageStatus.delivered;

  Widget statusIcon({double size = 16, Color color = Colors.grey}) {
    switch (status) {
      case MessageStatus.sent:
        return Icon(Icons.done, size: size, color: color.withOpacity(0.5));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: size, color: color.withOpacity(0.7));
      case MessageStatus.read:
        return Icon(Icons.done_all, size: size, color: CupertinoColors.systemBlue);
      default:
        return Icon(Icons.access_time_outlined, size: size, color: color.withOpacity(0.5));
    }
  }

  MessageModel({
    this.id,
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    required this.messageType,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedFor = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final nowIso = DateTime.now().toIso8601String();

    return MessageModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      messageId: json['messageId']?.toString()
          ?? json['_id']?.toString()
          ?? json['id']?.toString()
          ?? DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: json['conversation_id']?.toString() ?? json['conversationId']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? json['receiverId']?.toString() ?? '',
      messageType: json['message_type'] ?? json['messageType'] ?? 'text',
      content: MessageContent.fromJson(json['content'] ?? {}),
      status: MessageStatus.values.firstWhere(
            (e) => e.name == (json['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? json['timestamp'])?.toString() ?? nowIso,
      updatedAt: (json['updatedAt'] ?? json['updated_at'] ?? json['createdAt'])?.toString() ?? nowIso,
      isDeleted: json['isDeleted'] ?? false,
      deletedFor: List<String>.from(json['deletedFor'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_type': messageType,
      'content': content.toJson(),
      'status': status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
      'deletedFor': deletedFor,
    };
  }

  Map<String, dynamic> toSocketJson() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageType': messageType,
      'content': content.toJson(),
      'status': status.name,
    };
  }

  MessageModel copyWith({
    String? id,
    String? messageId,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? messageType,
    MessageContent? content,
    MessageStatus? status,
    String? createdAt,
    String? updatedAt,
    bool? isDeleted,
    List<String>? deletedFor,
  }) {
    return MessageModel(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedFor: deletedFor ?? this.deletedFor,
    );
  }
}

// Message content structure
class MessageContent {
  final String? text;
  final String? mediaUrl;
  final int? mediaSize;
  final double? mediaDuration;
  final String? thumbnailUrl;

  MessageContent({
    this.text,
    this.mediaUrl,
    this.mediaSize,
    this.mediaDuration,
    this.thumbnailUrl,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      text: json['text'],
      mediaUrl: json['mediaUrl'],
      mediaSize: json['mediaSize'],
      mediaDuration: json['mediaDuration'] != null
          ? (json['mediaDuration'] as num).toDouble()
          : null,
      thumbnailUrl: json['thumbnailUrl'],
    );
  }

  MessageContent copyWith({
    String? text,
    String? mediaUrl,
    int? mediaSize,
    double? mediaDuration,
    String? thumbnailUrl,
  }) {
    return MessageContent(
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaSize: mediaSize ?? this.mediaSize,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaSize': mediaSize,
      'mediaDuration': mediaDuration,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

// Conversation Model for Socket.IO chat
class Conversation {
  final String id;
  final String conversationId;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ApiUser>? participants;
  final List<String> deletedFor;

  Conversation({
    required this.id,
    required this.conversationId,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedFor = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: (json['unread_count'] ?? json['unreadCount']) is int
          ? (json['unread_count'] ?? json['unreadCount']) as int
          : 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      participants: json['participants'] != null
          ? List<ApiUser>.from(
          (json['participants'] as List).map((x) => ApiUser.fromJson(x)))
          : null,
      deletedFor: List<String>.from(json['deletedFor'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'lastMessage': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'participants': participants?.map((x) => x.toJson()).toList(),
      'deletedFor': deletedFor,
    };
  }

  Conversation copyWith({
    String? id,
    List<ApiUser>? participants,
    MessageModel? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    List<String>? deletedFor,
    DateTime? createdAt,
    DateTime? updatedAt
  }) {
    return Conversation(
      id: id ?? this.id,
      conversationId: conversationId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      deletedFor: deletedFor ?? this.deletedFor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Report Model for API
class Report {
  final String id;
  final String reporterId;
  final String targetId;
  final String targetType;
  final String reason;
  final String? description;
  final DateTime createdAt;
  final String status;

  Report({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.description,
    required this.createdAt,
    this.status = 'pending',
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      reporterId: json['reporter_id']?.toString() ?? json['reporterId']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? json['targetId']?.toString() ?? '',
      targetType: json['target_type'] ?? json['targetType'] ?? '',
      reason: json['reason'] ?? '',
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

// OnlineUser Model for meet feature
class OnlineUser {
  final String userId;
  final bool isInMeet;
  final double? latitude;
  final double? longitude;
  final DateTime lastSeen;
  final String? displayName;
  final String? profileImageUrl;
  final String? gender;
  final ApiUser? user;

  OnlineUser({
    required this.userId,
    this.isInMeet = false,
    this.latitude,
    this.longitude,
    required this.lastSeen,
    this.displayName,
    this.profileImageUrl,
    this.gender,
    this.user,
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      isInMeet: json['is_in_meet'] ?? json['isInMeet'] ?? false,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      lastSeen: DateTime.tryParse(json['last_seen'] ?? json['lastSeen'] ?? '') ?? DateTime.now(),
      displayName: json['display_name'] ?? json['displayName'],
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      gender: json['gender'],
      user: json['user'] != null ? ApiUser.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_in_meet': isInMeet,
      'latitude': latitude,
      'longitude': longitude,
      'last_seen': lastSeen.toIso8601String(),
      'display_name': displayName,
      'profile_image_url': profileImageUrl,
      'gender': gender,
      if (user != null) 'user': user!.toJson(),
    };
  }
}

// Type aliases for backward compatibility with existing code
typedef AppUser = ApiUser;
typedef Video = ApiVideo; 
typedef Comment = ApiComment;
typedef ChatMessage = MessageModel;
typedef ChatConversation = Conversation;