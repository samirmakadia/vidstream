import 'package:flutter/material.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:vidstream/screens/chat_screen.dart';
import 'package:vidstream/services/chat_service.dart';
import 'package:vidstream/storage/conversation_storage_drift.dart';

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
  }

  void _loadConversations() {
    _chatService.getUserConversations().listen((conversations) {

    }).onError((error) {
      print('Error loading conversations: $error');
    });
  }

  ApiUser? _getOtherParticipant(Conversation conversation) {
    final currentUserId = _authService.currentUser?.id ?? '';
    var otherUser = conversation.participants?.firstWhere(
          (user) => user.id != currentUserId
    );
    return otherUser;
  }

  int _getUnreadCount(Conversation conversation) {
    // For now, return 0 as unread count logic needs to be implemented in API
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          // stream is still connecting/loading
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final conversations = snapshot.data ?? [];
        if (conversations.isEmpty) {
          return _buildEmptyState();
        }
        return RefreshIndicator(
          onRefresh: () async {
            _loadConversations();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _buildChatTile(conversation);
            },
          ),
        );
      },
    );
  }

  // Widget _buildChatList() {
  //   if (_conversations.isEmpty) {
  //     return _buildEmptyState();
  //   }
  //
  //   return RefreshIndicator(
  //     onRefresh: _loadConversations,
  //     child: ListView.builder(
  //       padding: const EdgeInsets.symmetric(vertical: 8),
  //       itemCount: _conversations.length,
  //       itemBuilder: (context, index) {
  //         final conversation = _conversations[index];
  //         return _buildChatTile(conversation);
  //       },
  //     ),
  //   );
  // }

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
              child: profileImage == null
                  ? Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              )
                  : null,
            ),
            if (isUnread)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
          ],
        ),
        title: Text(
          displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Start conversation',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(conversation.updatedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(otherUserId: otherUser?.id ?? ''),
            ),
          ).then((_) => _loadConversations()); // Refresh on return
        },
      ),
    );
  }



}