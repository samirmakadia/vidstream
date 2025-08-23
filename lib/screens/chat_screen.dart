import 'package:flutter/material.dart';
import 'package:vidstream/services/chat_service.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import '../widgets/custom_image_widget.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;

  const ChatScreen({super.key, required this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  AppUser? _otherUser;
  String? _conversationId;
  bool _isLoading = true;
  bool _isSending = false;
  int _messagesSentWithoutReply = 0;
  bool _hasReceivedReply = false;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // Load other user data
      _otherUser = await _chatService.getUserById(widget.otherUserId);
      
      // Get or create conversation
      //_conversationId = await _chatService.getOrCreateConversation(widget.otherUserId);

      // Start listening to messages in real-time
      if (_conversationId != null) {
        _startListeningToMessages();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    }
  }

  void _startListeningToMessages() {
    if (_conversationId == null) return;
    
    _messagesSubscription?.cancel();
    bool isFirstLoad = true;
    
    _messagesSubscription = _chatService.listenToMessages(_conversationId!).listen(
      (messages) {
        if (mounted) {
          final previousMessageCount = _messages.length;
          setState(() {
            _messages = messages;
            _checkMessageLimitation();
          });
          
          // Auto-scroll to bottom
          if (isFirstLoad) {
            // Jump instantly on first load
            _scrollToBottomInstant();
            isFirstLoad = false;
          } else if (messages.length > previousMessageCount) {
            // Smooth scroll for new messages
            _scrollToBottom();
          }
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error listening to messages: $error')),
          );
        }
      },
    );
  }

  void _checkMessageLimitation() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    int sentWithoutReply = 0;
    bool receivedReply = false;

    // Check from the end (latest messages) backwards
    for (int i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      
      if (message.senderId == currentUserId) {
        sentWithoutReply++;
      } else {
        receivedReply = true;
        break;
      }
    }

    setState(() {
      _messagesSentWithoutReply = receivedReply ? 0 : sentWithoutReply;
      _hasReceivedReply = receivedReply || _messages.isEmpty;
    });
  }

  bool get _canSendMessage {
    return _hasReceivedReply || _messagesSentWithoutReply < 5;
  }

  Future<void> _sendMessage({String? mediaUrl, String messageType = 'text'}) async {
    if (!_canSendMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only send 5 messages until the other user replies'),
        ),
      );
      return;
    }

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && mediaUrl == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId != null && _conversationId != null) {
        await _chatService.sendMessage(
          conversationId: _conversationId!,
          messageType: messageType,
          content: {'text': messageText, 'media_url': mediaUrl},
        );

        _messageController.clear();
        // Messages will be updated automatically via the stream listener
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _otherUser?.profileImageUrl != null && _otherUser!.profileImageUrl!.isNotEmpty ?
            CustomImageWidget(
              imageUrl: _otherUser?.profileImageUrl ?? '',
              height: 35,
              width: 35,
              cornerRadius: 30,
            ) :
            CircleAvatar(
              radius: 17,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                      Icons.person,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    )
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _otherUser?.displayName ?? 'Loading...',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
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
        if (!_canSendMessage)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange.withValues(alpha: 0.1),
            child: Text(
              'You can only send ${5 - _messagesSentWithoutReply} more message(s) until ${_otherUser?.displayName ?? 'the other user'} replies',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _authService.currentUser?.uid;
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
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
                  _formatTime(message.sentAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead 
                        ? Icons.done_all 
                        : message.isDelivered 
                            ? Icons.done_all 
                            : Icons.done,
                    size: 14,
                    color: message.isRead 
                        ? Colors.blue 
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ],
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
              onPressed: _canSendMessage ? _pickAndSendImage : null,
              icon: const Icon(Icons.image),
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              onPressed: _canSendMessage ? _pickAndSendVideo : null,
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
                  enabled: _canSendMessage,
                  decoration: InputDecoration(
                    hintText: _canSendMessage 
                        ? 'Type a message...' 
                        : 'Wait for reply to continue',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _canSendMessage ? (_) => _sendMessage() : null,
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
    if (state == AppLifecycleState.resumed && _conversationId != null) {
      // Mark messages as read when user returns to the chat
      if (_conversationId != null && _messages.isNotEmpty) {
        final unreadMessageIds = _messages
            .where((msg) => msg.status != MessageStatus.read)
            .map((msg) => msg.id)
            .toList();
        if (unreadMessageIds.isNotEmpty) {
          _chatService.markMessagesAsRead(_conversationId!, unreadMessageIds);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}