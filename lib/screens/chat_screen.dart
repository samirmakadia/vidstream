import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidstream/services/auth_service.dart';
import 'package:vidstream/models/api_models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:vidstream/storage/message_storage_drift.dart';
import 'package:vidstream/utils/utils.dart';
import '../helper/navigation_helper.dart';
import '../repositories/api_repository.dart';
import '../services/chat_service.dart';
import '../services/socket_manager.dart';
import '../services/video_service.dart';
import '../utils/app_toaster.dart';
import '../widgets/banner_ad_with_loader.dart';
import '../widgets/custom_image_widget.dart';
import '../widgets/image_preview_screen.dart';
import 'home/bottomsheet/report_dialog.dart';
import 'other_user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? otherUserId;
  final String? conversationId;
  final String? name;
  final String? imageUrl;
  final Conversation? conversation;

  const ChatScreen({super.key, this.otherUserId, this.conversationId, this.name, this.imageUrl,  this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final db = MessageDatabase.instance;
  ApiUser? _otherUser;
  final bool _isLoading = false;
  bool initialScroll = false;
  late Stream<List<ChatMessage>> _messagesStream;
  String? otherUserId;

  @override
  void initState() {
    super.initState();
    final currentUserId = _authService.currentUser?.id;
    final otherUser = Utils.getOtherUserIdFromConversation(widget.conversationId, currentUserId, widget.otherUserId);
    otherUserId = widget.otherUserId ?? otherUser ?? '';
    final conversationId = widget.conversationId ?? (currentUserId != null && otherUserId != null ? Utils.generateConversationId(currentUserId, otherUserId!) : null);

    if (conversationId != null) {
      _messagesStream = db.watchMessagesForConversation(conversationId);
    }
    _loadOtherUser();
  }

  MessageModel? _getMessage({String? mediaUrl, int mediaSize = 0, double mediaDuration =0, String messageType = 'text'}) {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && mediaUrl == null) {
      AppToast.showError("Enter message or attach media");
      return null;
    }
    final nowIso = DateTime.now().toIso8601String();
    final currentUserId = _authService.currentUser?.id;
    final conversationId = widget.conversationId ?? Utils.generateConversationId(currentUserId!, otherUserId!);
    final content = MessageContent(
      text: _messageController.text.trim(),
      mediaUrl: mediaUrl ?? '',
      mediaSize: mediaSize,
      mediaDuration: mediaDuration,
      thumbnailUrl: '',
    );

    return MessageModel(
      messageId: Utils.generateMessageId(),
      conversationId: conversationId,
      senderId: currentUserId!,
      receiverId: otherUserId,
      messageType: messageType,
      content: content,
      status: MessageStatus.sent,
      createdAt: nowIso,
      updatedAt: nowIso,
    );

  }

  Future<void> _sendMessageWithModel(MessageModel msg) async {
    try {
      SocketManager().sendMessage(msg);
      _messageController.clear();
    } catch (e, stack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
    }
  }

  Future<void> _loadOtherUser() async {
    final user = await _chatService.getUserById(otherUserId!);
    if (mounted && user != _otherUser) {
      setState(() {
        _otherUser = user;
      });
    }
  }

  Future<void> _pickAndPreviewImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final File selectedImage = File(image.path);

    // Navigate to preview screen
    final shouldSend = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          imageFile: selectedImage,
          showUploadButton: true,
        ),
      ),
    );

    if (shouldSend == true) {
      _sendImage(selectedImage);
    }
  }

  Future<void> _sendImage(File selectedImage) async {
    MessageModel? _message = _getMessage(mediaUrl: selectedImage.path, messageType: 'image');
    if (_message == null) return;

    await MessageDatabase.instance.addOrUpdateMessage(_message);

    try {
      final uploadedUrl = await _uploadCommonFile(selectedImage.path);
      if (uploadedUrl != null) {
        print("✅ Image uploaded: $uploadedUrl");
        final updatedMessage = _message.copyWith(
          content: _message.content.copyWith(
            text: _message.content.text,
            mediaUrl: uploadedUrl.url,
            mediaSize: uploadedUrl.size,
            mediaDuration: uploadedUrl.duration,
            thumbnailUrl: uploadedUrl.thumbnailUrl,
          ),
        );
        await _sendMessageWithModel(updatedMessage);
      }
    } catch (e) {
      debugPrint("❌ Error sending image: $e");
      if (mounted) {
        _showErrorSnackBar('Failed to send image: $e');
      }
    }
  }

  Future<ApiCommonFile?> _uploadCommonFile(String filePath) async {
    try {
      final videoService = VideoService();

      final uploadedFile = await videoService.uploadCommonFile(
        filePath: filePath,
        type: 'image',
      );

      if (uploadedFile == null) {
        _showErrorSnackBar("Failed to upload file to server");
        return null;
      }

      setState(() {
        print("Uploaded file URL: ${uploadedFile.url}");
      });

      return uploadedFile;
    } catch (e) {
      _showErrorSnackBar('Failed to upload file: $e');
      return null;
    }
  }

  Future<void> _deleteConversation() async {
    try {
      await _chatService.deleteChatConversation(widget.conversation?.id ?? '');
      await MessageDatabase.instance.deleteMessagesByConversationId(widget.conversation?.id ?? '');

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
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    final isOwner = message.senderId == currentUserId;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (isOwner)
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
        if (!isOwner)
          const PopupMenuItem<String>(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.report, color: Colors.orange),
                SizedBox(width: 8),
                Text("Report"),
              ],
            ),
          ),
      ],
    );

    if (result == 'delete') {
      try {
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
    } else if (result == 'report') {
      await _reportChatMessage(context, message);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _reportChatMessage(BuildContext context, ChatMessage message) async {
    final reasons = {
      'Spam': 'spam',
      'Inappropriate content': 'inappropriate_content',
      'Harassment': 'harassment',
      'Fake Account': 'fake_account',
      'Other': 'other',
    };
    await showDialog(
      context: context,
      builder: (_) => ReportDialog(
        scaffoldContext: context,
        title: 'Report Message',
        reasons: reasons,
        isDescriptionRequired: true,
        onSubmit: ({required reason, String? description}) async {
          return await _handleReport(
            targetId: message.id ?? '',
            targetType: 'Message',
            reason: reason,
            description: description,
          );
        },
      ),
    );
  }

  Future<String> _handleReport({
    required String targetId,
    required String targetType,
    required String reason,
    String? description,
  }) async {
    final currentUserId = ApiRepository.instance.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not logged in. Cannot submit report.'), backgroundColor: Colors.red),
      );
      return '';
    }
    try {
      final result = await ApiRepository.instance.reports.reportContent(
        reporterId: currentUserId,
        targetId: targetId,
        targetType: targetType,
        reason: reason,
        description: description,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: result.toLowerCase().contains('success') ? Colors.green : Colors.red,
        ),
      );
      return result;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return '';
    }
  }

  void _navigateToUserProfile(ApiUser user) {
    NavigationHelper.navigateWithAd(
      context: context,
      destination: OtherUserProfileScreen(
        userId: user.id,
        displayName: user.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildChatAppBar(context),
      body: Column(
        children: [
          BannerAdWithLoader(),
          Expanded(child: _isLoading ? _buildLoadingState() : _buildChatBody()),
        ],
      ),
    );
  }

  AppBar buildChatAppBar(BuildContext context) {
    return AppBar(
      title: GestureDetector(
        onTap: () {
          if (_otherUser != null){
            _navigateToUserProfile(_otherUser!);
          }
        },
        child: Row(
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
                child: Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.primary)
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _otherUser?.displayName ?? widget.name ?? 'Loading...',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
          ],
        ),
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
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center( child: _buildEmptyState());
        }
        final messages = snapshot.data ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          reverse: true,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == _authService.currentUser?.uid;
            if (!isMe && message.status != MessageStatus.read) {
              SocketManager().sendSeenEvent(message,_authService.currentUser?.uid ?? '');
            }
            print("Message seen: ${message.content.text}, Status: ${message.status}, id : ${message.id}");
            print("Message createdAt:  ${message.createdAt}");
            print("Message mediaUrl:  ${message.content.mediaUrl}");
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
                padding: EdgeInsets.symmetric(horizontal: message.messageType == 'image' ? 5 : 16, vertical: message.messageType == 'image' ? 5 : 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0),
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
                    if (message.messageType == 'image' && message.content.mediaUrl != null && message.content.mediaUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final isNetwork = message.content.mediaUrl!.startsWith('http');
                          NavigationHelper.navigateWithAd(
                            context: context,
                            destination: ImagePreviewScreen(
                              imageFile: isNetwork ? null : File(message.content.mediaUrl!),
                              imageUrl: isNetwork ? message.content.mediaUrl! : null,
                              showUploadButton: false,
                            ),
                          );
                        },
                        child: CustomImageWidget(
                          imageUrl: message.content.mediaUrl ?? '',
                          height: 200,
                          width: 200,
                          cornerRadius: 12,
                        ),
                      ),
                    if (message.message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          ),
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
                    message.statusIcon(
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
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
              onPressed: _pickAndPreviewImage,
              icon: const Icon(Icons.image),
              color: Theme.of(context).colorScheme.primary,
            ),
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
                  textInputAction: TextInputAction.newline,
                  //onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
                builder: (context, value, _) {
                final _canSendMessage = value.text.trim().isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: _canSendMessage ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () async {
                      if (_canSendMessage) {
                        MessageModel? tmpMessage = _getMessage();
                        if (tmpMessage != null) {
                          await MessageDatabase.instance.addOrUpdateMessage(tmpMessage);
                          _sendMessageWithModel(tmpMessage);
                        }
                      }
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                );
              }
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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}