import 'package:flutter/material.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:vidstream/storage/message_storage_drift.dart';
import 'package:vidstream/utils/utils.dart';
import '../services/chat_service.dart';
import '../services/socket_manager.dart';
import '../utils/app_toaster.dart';
import '../widgets/custom_image_widget.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? conversationId;
  final String? name;
  final String? imageUrl;
  final Conversation? conversation;

  const ChatScreen({super.key, required this.otherUserId, this.conversationId, this.name, this.imageUrl,  this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final db = MessageDatabase.instance;
  // late final stream;
  ApiUser? _otherUser;

  final bool _isLoading = false;
  bool _isSending = false;
  bool initialScroll = false;
  final bool _canSendMessage = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOtherUser();
  }


  Future<void> _sendMessage({String? mediaUrl, String messageType = 'text'}) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && mediaUrl == null) {
      AppToast.showError("Enter message or attach media");
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final currentUserId = _authService.currentUser?.id;
      final conversationId = widget.conversationId ?? Utils.generateConversationId(currentUserId!, widget.otherUserId);
      if (currentUserId == null ) return;


      final content = MessageContent(
        text: messageText,
        mediaUrl: mediaUrl,
        mediaSize: 0,
        mediaDuration: 0,
        thumbnailUrl: '',
      );

      final message = Message(
        messageId: Utils.generateMessageId(),
        conversationId: conversationId,
        senderId: currentUserId,
        receiverId: widget.otherUserId,
        messageType: messageType,
        content: content,
        status: MessageStatus.sent,
        createdAt: '',
        updatedAt: '',
      );

      _messageController.clear();
      SocketManager().sendMessage(message);
      debugPrint("✅ Message sent: ${message.messageId}");
    } catch (e, stack) {
      debugPrint("❌ Error sending message: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _loadOtherUser() async {
    _otherUser = await _chatService.getUserById(widget.otherUserId);
    setState(() {});
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // In a real app, you would upload the image to cloud storage first
      // For now, we'll just send the local path as a placeholder
      await _sendMessage(
        mediaUrl: 'https://example.com/placeholder-image.jpg',
        messageType: 'image',
      );
    }
  }

  Future<void> _pickAndSendVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      // In a real app, you would upload the video to cloud storage first
      // For now, we'll just send the local path as a placeholder
      await _sendMessage(
        mediaUrl: 'https://example.com/placeholder-video.mp4',
        messageType: 'video',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomInstant() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _deleteConversation() async {
    try {
      await _chatService.deleteChatConversation(widget.conversation?.id ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onMessageLongPress(ChatMessage message, Offset tapPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text("Delete"),
            ],
          ),
        ),
      ],
    );

    if (result == 'delete') {
      try {
        print('messageid of message is:${message.id}');
        await _chatService.deleteChatMessage(message.id ?? '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            widget.imageUrl != null && widget.imageUrl!.isNotEmpty ?
            CustomImageWidget(
              imageUrl: widget.imageUrl ?? _otherUser?.profileImageUrl ?? '',
              height: 35,
              width: 35,
              cornerRadius: 30,
            ) :
            CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: _otherUser?.profileImageUrl != null ? NetworkImage(_otherUser!.profileImageUrl!) : null,
                child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary)
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _otherUser?.displayName ?? widget.name ?? 'Loading...',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteConversation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete Conversation'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildChatBody(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Expanded(
          child: _buildMessagesList(),
        ),
        _buildMessageInput(),
      ],
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
            'Start the conversation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to ${_otherUser?.displayName ?? 'this user'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final currentUserId = _authService.currentUser?.id;
    final conversationId = widget.conversationId ?? Utils.generateConversationId(currentUserId!, widget.otherUserId);
    return StreamBuilder<List<ChatMessage>>(
      stream: db.watchMessagesForConversation(conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No messages yet. \nStart the conversation!', textAlign: TextAlign.center,),
          );
        }
        final messages = snapshot.data ?? [];
        _scrollToBottomInstant();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == _authService.currentUser?.uid;
            if (!isMe && message.status != MessageStatus.read) {
              SocketManager().sendSeenEvent(message,_authService.currentUser?.uid ?? '');
            }
            print("Message seen: ${message.content.text}, Status: ${message.status}, id : ${message.id}");
            print("Message createdAt:  ${message.createdAt}");
            return _buildMessageBubble(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return GestureDetector(
      onLongPressStart: (details) {
        _onMessageLongPress(message, details.globalPosition);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.messageType == 'image')
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[300],
                        ),
                        child: const Icon(Icons.image, size: 50, color: Colors.grey),
                      )
                    else if (message.messageType == 'video')
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[300],
                        ),
                        child: const Icon(Icons.play_circle_outline, size: 50, color: Colors.grey),
                      ),
                    if (message.message.isNotEmpty)
                      Text(
                        message.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(DateTime.parse(message.createdAt)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    message.statusIcon(size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Media buttons
            IconButton(
              onPressed: _pickAndSendImage,
              icon: const Icon(Icons.image),
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              onPressed: _pickAndSendVideo,
              icon: const Icon(Icons.videocam),
              color: Theme.of(context).colorScheme.primary,
            ),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: true,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _canSendMessage && !_isSending
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _canSendMessage && !_isSending ? _sendMessage : null,
                icon: _isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.conversationId != null) {
      // Mark messages as read when user returns to the chat
      if (widget.conversationId != null) {
        // TODO mark messages as read
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}