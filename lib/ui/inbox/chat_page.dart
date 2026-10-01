import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:picture_live/ui/inbox/widget/message_widget.dart';
import 'package:picture_live/ui/inbox/widget/recorder_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../data/remote/firebase/inbox_services.dart';
import '../../theme/app_theme.dart';

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerAvatar;

  const ChatPage({super.key, required this.peerId, required this.peerName, required this.peerAvatar});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final String currentUserAvatar = FirebaseAuth.instance.currentUser?.photoURL ?? "";
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription? _unreadSubscription;
  StreamSubscription? _newMessagesSubscription;
  StreamSubscription? _messageUpdatesSubscription;

  List<ChatMessage> _messages = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isUploadingMedia = false;
  bool _isRecordingVoice = false;

  // --- EMOJI ASSETS LIST ---
  // Matches the files in your screenshot
  final List<String> _emojiAssets = [
    // --- POSITIVE & VIBES ---
    'happy.webp',
    'xd.webp', // Laughing
    'sunglass.webp',
    'amazed.webp',
    'yummy.webp',

    // --- LOVE & AFFECTION ---
    'heart.webp',
    'kissing.webp',
    'lip_kiss.webp',
    'hug.webp',
    'blessed.webp',

    // --- GESTURES (APPROVAL) ---
    'like.webp',
    'clapping.webp',

    // --- NEUTRAL / SKEPTICAL / SNEAKY ---
    'thinking.webp',
    'hidden_look.webp',
    'silent.webp',
    'ignore.webp',

    // --- SAD & UNWELL ---
    'sad.webp',
    'crying.webp',
    'sick.webp',
    'vomit.webp',

    // --- ANGRY & AGGRESSIVE ---
    'angry.webp',
    'punch.webp',
    'fuk.webp',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    InboxService.markAsRead(widget.peerId);
    _startUnreadCountGuard();
    _scrollController.addListener(_scrollListener);
  }

  // ... _loadInitialMessages, _listenToNewMessages, _listenToMessageUpdates, _scrollListener, _loadOlderMessages, _startUnreadCountGuard, dispose, _handleSend, _handleImagePick, _handleCameraPick, _handleVideoPick, _showMediaOptions ...
  // (Keep these exactly as they were in your provided code)

  Future<void> _loadInitialMessages() async {
    setState(() => _isLoadingInitial = true);

    final messages = await InboxService.getInitialMessages(widget.peerId, limit: 20);

    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoadingInitial = false;
      });

      _listenToNewMessages();
      _listenToMessageUpdates();
    }
  }

  void _listenToNewMessages() {
    final newestMessageKey = _messages.isNotEmpty ? _messages.last.id : null;
    _newMessagesSubscription?.cancel();
    _newMessagesSubscription = InboxService.listenToNewMessages(widget.peerId, newestMessageKey).listen((newMessage) {
      if (newMessage != null && mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);
          }
        });
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      }
    });
  }

  void _listenToMessageUpdates() {
    _messageUpdatesSubscription?.cancel();
    _messageUpdatesSubscription = InboxService.listenToMessageUpdates(widget.peerId).listen((updatedMessage) {
      if (updatedMessage != null && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
          if (index != -1) {
            _messages[index] = updatedMessage;
          }
        });
      }
    });
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent * 0.85;
    if (_scrollController.offset >= threshold && !_isLoadingMore && _hasMore) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final oldestMessageKey = _messages.first.id;
    final olderMessages = await InboxService.loadOlderMessages(widget.peerId, oldestMessageKey, limit: 20);
    if (mounted) {
      setState(() {
        if (olderMessages.isEmpty) {
          _hasMore = false;
        } else {
          _messages.insertAll(0, olderMessages);
        }
        _isLoadingMore = false;
      });
    }
  }

  void _startUnreadCountGuard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final unreadRef = FirebaseDatabase.instance.ref('user_chats/$uid/${widget.peerId}/unreadCount');
    _unreadSubscription = unreadRef.onValue.listen((event) {
      final count = (event.snapshot.value as num?)?.toInt() ?? 0;
      if (count > 0) {
        unreadRef.set(0);
      }
    });
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _newMessagesSubscription?.cancel();
    _messageUpdatesSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    InboxService.sendMessage(widget.peerId, text);
    _textController.clear();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // --- MEDIA HANDLERS (Same as before) ---
  Future<void> _handleImagePick() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;
      setState(() => _isUploadingMedia = true);
      final success = await InboxService.sendImageMessage(widget.peerId, File(image.path));
      setState(() => _isUploadingMedia = false);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send image')));
      }
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleCameraPick() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image == null) return;
      setState(() => _isUploadingMedia = true);
      final success = await InboxService.sendImageMessage(widget.peerId, File(image.path));
      setState(() => _isUploadingMedia = false);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send image')));
      }
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleVideoPick() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video == null) return;
      setState(() => _isUploadingMedia = true);
      final success = await InboxService.sendVideoMessage(widget.peerId, File(video.path));
      setState(() => _isUploadingMedia = false);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send video')));
      }
    } catch (e) {
      setState(() => _isUploadingMedia = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleCameraPick();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: const Text('Video (max 15s)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleVideoPick();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW EMOJI BOTTOM SHEET ---
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allows sheet to go higher if needed
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: controller,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _emojiAssets.length,
                    itemBuilder: (context, index) {
                      final assetName = _emojiAssets[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _handleSendEmoji(assetName);
                        },
                        child: Image.asset('assets/emojis/$assetName', fit: BoxFit.contain),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSendEmoji(String assetName) {
    InboxService.sendEmojiMessage(widget.peerId, assetName);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(child: _buildMessagesList()),
            if (_isUploadingMedia) _buildUploadingIndicator(),
            _isRecordingVoice ? _buildVoiceRecorder() : _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ... _buildUploadingIndicator, _buildVoiceRecorder, _buildMessagesList (same as before) ...
  Widget _buildUploadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.3),
      child: const Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Uploading...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildVoiceRecorder() {
    return VoiceRecorderWidget(
      onRecordingComplete: (audioFile, duration) async {
        setState(() {
          _isRecordingVoice = false;
          _isUploadingMedia = true;
        });

        // Perform the upload
        final success = await InboxService.sendVoiceMessage(widget.peerId, audioFile, duration);

        if (mounted) {
          setState(() => _isUploadingMedia = false);

          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send voice message')));
          }
        }
      },
      onCancel: () {
        setState(() => _isRecordingVoice = false);
      },
    );
  }

  Widget _buildMessagesList() {
    if (_isLoadingInitial) {
      return Center(child: CircularProgressIndicator(color: AppColors.pinkLight));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text("Say Hi! 👋", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      );
    }
    final reversedMessages = _messages.reversed.toList();
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      itemCount: reversedMessages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == reversedMessages.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final msg = reversedMessages[index];
        final isMe = msg.senderId == currentUserId;
        if (!isMe && !msg.isRead) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            InboxService.markMessageAsRead(widget.peerId, msg.id);
          });
        }
        final bool isFirstInSequence =
            index == reversedMessages.length - 1 || reversedMessages[index + 1].senderId != msg.senderId;
        final bool isLastInSequence = index == 0 || reversedMessages[index - 1].senderId != msg.senderId;
        return _buildMessageRow(msg, isMe, isFirstInSequence, isLastInSequence);
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF5A189A),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  backgroundImage: widget.peerAvatar.isNotEmpty ? CachedNetworkImageProvider(widget.peerAvatar) : null,
                  backgroundColor: Colors.white24,
                  radius: 18,
                  child: widget.peerAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                Positioned(
                  width: 46.8,
                  height: 46.8,
                  child: IgnorePointer(child: ActiveFrameWidget(userId: widget.peerId, size: 46.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.peerName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'delete') {
                InboxService.deleteConversation(widget.peerId);
                Navigator.pop(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete Conversation', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- UPDATED MESSAGE ROW TO HANDLE EMOJI CONTAINER STYLE ---
  Widget _buildMessageRow(ChatMessage msg, bool isMe, bool isFirstInGroup, bool isLastInGroup) {
    final time = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));
    final bool showAvatar = isLastInGroup;

    final bool isMediaMessage =
        msg.type == MessageType.emoji || msg.type == MessageType.image || msg.type == MessageType.video;

    return Padding(
      padding: EdgeInsets.only(top: isFirstInGroup ? 8 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: widget.peerAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(widget.peerAvatar)
                          : null,
                      child: widget.peerAvatar.isEmpty
                          ? const Icon(Icons.person, size: 14, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      width: 36.4,
                      height: 36.4,
                      child: IgnorePointer(child: ActiveFrameWidget(userId: widget.peerId, size: 36.4)),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(msg, isMe),
              child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: isMediaMessage
                  ? null
                  : BoxDecoration(
                      color: isMe ? const Color(0xFF0084FF) : const Color(0xFFE4E6EB),
                      borderRadius: _getBorderRadius(isMe, isFirstInGroup, isLastInGroup),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
              padding: isMediaMessage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(msg, isMe),

                  if (isMediaMessage) const SizedBox(height: 4),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF65676B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: msg.isRead ? Colors.lightBlueAccent : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
           ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            if (showAvatar)
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: currentUserAvatar.isNotEmpty
                          ? CachedNetworkImageProvider(currentUserAvatar)
                          : null,
                      child: currentUserAvatar.isEmpty
                          ? const Icon(Icons.person, size: 14, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      width: 36.4,
                      height: 36.4,
                      child: IgnorePointer(child: ActiveFrameWidget(userId: currentUserId, size: 36.4)),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(width: 28),
          ],
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.type == MessageType.text)
                  ListTile(
                    leading: const Icon(Icons.copy, color: Colors.white),
                    title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.text));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      InboxService.deleteMessage(widget.peerId, msg.id);
                      Navigator.pop(context);
                    },
                  ),
                if (!isMe && msg.type != MessageType.text)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No options available', style: TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isMe) {
    switch (msg.type) {
      case MessageType.image:
        return ImageMessageBubble(imageUrl: msg.mediaUrl!, isMe: isMe);

      case MessageType.video:
        return VideoMessageBubble(videoUrl: msg.mediaUrl!, thumbnailUrl: msg.thumbnailUrl, duration: msg.mediaDuration);

      case MessageType.voice:
        return VoiceMessageBubble(audioUrl: msg.mediaUrl!, duration: msg.mediaDuration ?? 0, isMe: isMe);

      case MessageType.emoji:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Image.asset(
            'assets/emojis/${msg.mediaUrl}',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
            },
          ),
        );

      case MessageType.text:
        return Text(
          msg.text,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF050505),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  BorderRadius _getBorderRadius(bool isMe, bool isFirst, bool isLast) {
    const double r = 18.0;
    const double small = 4.0;
    if (isMe) {
      return BorderRadius.only(
        topLeft: Radius.circular(r),
        bottomLeft: Radius.circular(r),
        topRight: Radius.circular(isFirst ? r : small),
        bottomRight: Radius.circular(isLast ? 0 : small),
      );
    } else {
      return BorderRadius.only(
        topRight: Radius.circular(r),
        bottomRight: Radius.circular(r),
        topLeft: Radius.circular(isFirst ? r : small),
        bottomLeft: Radius.circular(isLast ? 0 : small),
      );
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(right: 12),
            icon: const Icon(Icons.attach_file, color: Color(0xFF8E8E93)),
            onPressed: _showMediaOptions,
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(right: 12),
            icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF8E8E93)),
            onPressed: _showEmojiPicker,
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(right: 8),
            icon: const Icon(Icons.mic, color: Color(0xFF8E8E93)),
            onPressed: () {
              setState(() => _isRecordingVoice = true);
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFF4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFF5A189A), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
