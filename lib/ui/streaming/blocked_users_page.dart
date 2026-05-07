import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import 'package:intl/intl.dart';

class BlockedUsersPage extends StatelessWidget {
  final String roomId;
  final String roomType; // 'audio' or 'video'

  const BlockedUsersPage({
    super.key,
    required this.roomId,
    required this.roomType,
  });

  @override
  Widget build(BuildContext context) {
    final stream = roomType == 'audio'
        ? RoomService.getBlockedUsersStream(roomId)
        : LiveStreamService.getBlockedUsersStream(roomId);

    return Scaffold(
      backgroundColor: const Color(0xFF1a0e18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Blocked Users', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
            return const Center(
              child: Text(
                'No blocked users in this room.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final blockedUsersMap = Map<dynamic, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );

          final List<String> userIds = blockedUsersMap.keys.map((k) => k.toString()).toList();

          return ListView.builder(
            itemCount: userIds.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final userId = userIds[index];
              final expiry = blockedUsersMap[userId] as int;

              return FutureBuilder(
                future: ProfileService.getUserProfile(userId),
                builder: (context, profileSnapshot) {
                  if (!profileSnapshot.hasData) {
                    return const SizedBox(height: 72);
                  }

                  final userData = profileSnapshot.data!.data() as Map<String, dynamic>?;
                  final String userName = userData?['displayName'] ?? 'Unknown User';
                  final String? photoUrl = userData?['photoUrl'] ?? userData?['profilePicture'];

                  String expiryText = '';
                  if (expiry == -1) {
                    expiryText = 'Permanent Ban';
                  } else {
                    final date = DateTime.fromMillisecondsSinceEpoch(expiry);
                    expiryText = 'Expires: ${DateFormat('dd MMM, hh:mm a').format(date)}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        expiryText,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _confirmUnblock(context, userName, userId),
                        child: const Text('Unblock', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _confirmUnblock(BuildContext context, String userName, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        title: const Text('Unblock User', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to unblock $userName?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (roomType == 'audio') {
                await RoomService.unblockUser(roomId, userId);
              } else {
                await LiveStreamService.unblockUser(roomId, userId);
              }
            },
            child: const Text('Unblock', style: TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }
}
