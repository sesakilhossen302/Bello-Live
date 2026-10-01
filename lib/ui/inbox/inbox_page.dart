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
import '../../core/localization/app_localizations.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A189A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context).navInbox,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<ConversationSummary>>(
        stream: InboxService.getUserChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)));
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E42),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5A189A).withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 50,
                        color: Color(0xFF5A189A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context).noMessagesYet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Start a new conversation",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
              indent: 85,
            ),
            itemBuilder: (context, index) {
              final summary = chats[index];
              return Dismissible(
                key: Key(summary.peerId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  InboxService.deleteConversation(summary.peerId);
                },
                child: _InboxTile(summary: summary),
              );
            },
          );
        },
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final ConversationSummary summary;

  const _InboxTile({required this.summary});

  String _getLastMessageDisplay(BuildContext context) {
    switch (summary.lastMessageType) {
      case MessageType.emoji:
        return '😊 ${AppLocalizations.of(context).stickerMsg}';
      case MessageType.image:
        return '📷 ${AppLocalizations.of(context).photoMsg}';
      case MessageType.video:
        return '🎥 ${AppLocalizations.of(context).videoMsg}';
      case MessageType.voice:
        return '🎤 ${AppLocalizations.of(context).voiceMsg}';
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
        String name = AppLocalizations.of(context).loading;
        String photoUrl = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['displayName'] ?? AppLocalizations.of(context).unknownUser;
          photoUrl = data['photoUrl'] ?? "";
        }

        final timeString = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(summary.timestamp));

        final bool isMe = summary.lastSenderId == currentUserId;

        return ListTile(
          onTap: () {
            context.push(Routes.chat.path, extra: {'peerId': summary.peerId, 'peerName': name, 'peerAvatar': photoUrl});
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                    border: Border.all(color: const Color(0xFF5A189A).withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: ClipOval(
                    child: photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Color(0xFF8E8E93)),
                          )
                        : const Icon(Icons.person, color: Color(0xFF8E8E93)),
                  ),
                ),
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: summary.unreadCount > 0 ? Colors.white : Colors.white60,
                  fontWeight: summary.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                children: [
                  if (isMe)
                    TextSpan(
                      text: "${AppLocalizations.of(context).you}: ",
                      style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.normal),
                    ),
                  TextSpan(text: _getLastMessageDisplay(context)),
                ],
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeString, style: const TextStyle(color: Color(0xFF5A189A), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              if (summary.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5A189A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    summary.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}