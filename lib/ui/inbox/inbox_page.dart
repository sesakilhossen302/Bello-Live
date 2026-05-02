import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../data/remote/firebase/inbox_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Text(
                      'Inbox',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // --- Chat List ---
              Expanded(
                child: StreamBuilder<List<ConversationSummary>>(
                  stream: InboxService.getUserChatsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.pinkLight));
                    }

                    final chats = snapshot.data ?? [];

                    if (chats.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(height: 10),
                            Text("No messages yet", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        return _InboxTile(summary: chats[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this to your InboxPage file, replacing the existing _InboxTile

class _InboxTile extends StatelessWidget {
  final ConversationSummary summary;

  const _InboxTile({required this.summary});

  // Helper to get the display text with icon based on message type
  String _getLastMessageDisplay() {
    switch (summary.lastMessageType) {
      case MessageType.emoji:
        return '😊 Sticker';
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.text:
      default:
        return summary.lastMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: ProfileService.getUserProfile(summary.peerId),
      builder: (context, snapshot) {
        String name = "Loading...";
        String photoUrl = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['displayName'] ?? "Unknown User";
          photoUrl = data['photoUrl'] ?? "";
        }

        final timeString = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(summary.timestamp));

        final bool isMe = summary.lastSenderId == currentUserId;

        return ListTile(
          onTap: () {
            context.push(Routes.chat.path, extra: {'peerId': summary.peerId, 'peerName': name, 'peerAvatar': photoUrl});
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: SizedBox(
            width: 55,
            height: 55,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.pinkLight.withValues(alpha: 0.5)),
                  ),
                  child: ClipOval(
                    child: photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                    )
                        : const Icon(Icons.person, color: Colors.white),
                  ),
                ),
                // Overlay the Frame (55 * 1.3 = 71.5)
                Positioned(
                  width: 71.5,
                  height: 71.5,
                  child: IgnorePointer(
                    child: ActiveFrameWidget(userId: summary.peerId, size: 71.5),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: summary.unreadCount > 0 ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontWeight: summary.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Roboto',
                  fontSize: 14,
                ),
                children: [
                  if (isMe)
                    TextSpan(
                      text: "You: ",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.normal),
                    ),
                  TextSpan(text: _getLastMessageDisplay()),
                ],
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeString, style: TextStyle(color: AppColors.pinkLight, fontSize: 12)),
              const SizedBox(height: 6),
              if (summary.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    summary.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}