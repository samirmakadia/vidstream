import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/chat_screen.dart';
import 'package:vidstream/services/chat_service.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';

import '../services/socket_manager.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final db = ConversationDatabase.instance;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    _chatService.getUserConversations().listen((conversations) {
      print('Loaded ${conversations.length} conversations');
    }).onError((error) {
      print('Error loading conversations: $error');
    });
  }

  ApiUser? _getOtherParticipant(Conversation conversation) {
    final currentUserId = _authService.currentUser?.id ?? '';
    var otherUser = conversation.participants?.firstWhere((user) => user.id != currentUserId);
    return otherUser;
  }

  int _getUnreadCount(Conversation conversation) {
    return 0;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _buildChatList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildChatList() {
    final currentUserId = _authService.currentUser?.id ?? '';
    return StreamBuilder<List<Conversation>>(
      stream: db.watchAllConversations(currentUserId),
      builder: (context, snapshot) {
        print(' StreamBuilder: ${snapshot.error}');
        print(snapshot.stackTrace);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final conversations = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            _loadConversations();
          },
          child: conversations.isEmpty
              // Wrap empty state with scrollable
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: _buildEmptyState(),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    print('Building chat tile → id: ${conversation.conversationId}, name: ${conversation.participants?.map((u) => u.displayName).join(', ')}');
                    return _buildChatTile(conversation);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with users from the Meet tab',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Conversation conversation) {
    final otherUser = _getOtherParticipant(conversation);
    final unreadCount = _getUnreadCount(conversation);
    final isUnread = unreadCount > 0;

    final displayName = otherUser?.displayName ?? 'Unknown User';
    final profileImage = otherUser?.profileImageUrl;
    print(conversation.lastMessage?.content.text);

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                    otherUserId: otherUser?.id ?? '',
                    conversationId: conversation.conversationId,
                    name: displayName,
                    imageUrl: profileImage,
                    conversation: conversation),
              ),
            )
            .then((_) => _loadConversations());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.07),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                  child: profileImage == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                          size: 26,
                        )
                      : null,
                ),
                // Online indicator
                if (otherUser?.isOnline == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                // Unread badge
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                        ),
                  ),
                  getLastMsgBaseOnType(conversation),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(conversation.lastMessage != null ? DateTime.parse(conversation.lastMessage!.createdAt) : conversation.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isUnread)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget getLastMsgBaseOnType(Conversation conversation) {
    final unreadCount = _getUnreadCount(conversation);
    final isUnread = unreadCount > 0;

    final lastMessage = conversation.lastMessage;

    if (lastMessage == null) {
      return Text(
        'Start conversation',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (lastMessage.messageType == "text") {
      return Text(
        lastMessage.content.text ?? "",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (lastMessage.messageType == "image") {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.image, size: 18, color: Color(0xFFAEAEAE)),
          const SizedBox(width: 4),
          Text(
            "Photo",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                ),
          ),
        ],
      );
    } else {
      // fallback for unsupported types
      return Text(
        'Unsupported message',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}
