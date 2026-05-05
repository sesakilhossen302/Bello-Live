import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/active_frame_widget.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../data/remote/firebase/room_services.dart';
import '../../../navigation/routes.dart';
import '../../profile/profile_page.dart';
import 'follow_list_bottomsheet.dart';
import 'host_actions_bottomsheet.dart';
import 'report_user_bottomsheet.dart';

/// A bottom sheet that displays detailed info about a user.
class ProfileInfoBottomSheet extends StatelessWidget {
  final String userId;
  final String? hostId;
  final String? roomId;
  final bool isSeated;
  final bool isCoHost;

  const ProfileInfoBottomSheet({
    super.key,
    required this.userId,
    this.hostId,
    this.roomId,
    this.isSeated = false,
    this.isCoHost = false,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // --- UPDATED LOGIC (Null-safe) ---
    final bool isHost = hostId != null && userId == hostId;
    final bool isCurrentUser = userId == currentUserId;
    final bool isCurrentUserTheHost = hostId != null && currentUserId == hostId;

    return StreamBuilder<DocumentSnapshot>(
      stream: ProfileService.getUserProfileStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String userName = data['displayName'] ?? 'Unknown User';
        final String? userPicture = data['photoUrl'];
        final int followerCount = data['followerCount'] ?? 0;
        final int followingCount = data['followingCount'] ?? 0;
        final int level = getSentLevel(data['totalSent'] ?? 0);

        return SafeArea(
          child: Stack(
            children: [
              // --- BACKGROUND IMAGE ---
              Positioned.fill(
                child: Image.asset(
                  "assets/images/short_profile_bg.jpeg", // Ensure this asset exists
                  fit: BoxFit.cover,
                ),
              ),

              // --- EXISTING SVGA ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 250,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SVGAEasyPlayer(assetsName: "assets/svga/profile.svga", fit: BoxFit.cover),
                ),
              ),

              // --- EXISTING CONTENT ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isHost ? '@Host' : '@User',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        // --- MODIFIED HEADER LOGIC ---
                        if (!isCurrentUser) ...[
                          // I am the HOST viewing another user AND we are actually inside a room
                          if (isCurrentUserTheHost && roomId != null)
                            IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close this sheet
                                showHostActionsBottomSheet(
                                  context,
                                  targetUserId: userId,
                                  targetUserName: userName,
                                  roomId: roomId!, // Safe to force unwrap here
                                );
                              },
                            )
                          // I am a standard USER viewing another user (or viewed from main Profile page)
                          else
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // Close this sheet
                                showReportUserBottomSheet(context, reportedUserId: userId, reportedUserName: userName);
                              },
                              child: const Text(
                                'Report',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                        // --- END MODIFIED LOGIC ---
                      ],
                    ),
                    // --- Profile Picture with Frame ---
                    SizedBox(
                      width: 100, // radius 50 * 2
                      height: 100,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: userPicture != null && userPicture.isNotEmpty
                                ? NetworkImage(userPicture)
                                : null,
                            child: (userPicture == null || userPicture.isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                          // Overlay the Frame (100 * 1.3 = 130)
                          Positioned(
                            width: 130,
                            height: 130,
                            child: IgnorePointer(child: ActiveFrameWidget(userId: userId, size: 130)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    // --- User Info ---
                    AutoScrollText(
                      text: userName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dynamic Level Image
                        Image.asset(
                          'assets/images/levels/rank_caifu_cf_$level.png',
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                        const SizedBox(width: 12),
                        // User ID
                        Row(
                          children: [
                            Text(
                              'ID: ${data['displayId'] ?? 'N/A'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Diamonds count
                        Row(
                          children: [
                            const Icon(Icons.diamond_outlined, color: Colors.cyan, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${data['diamonds'] ?? 0}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- Stats Row ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Followers
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(); // Close this sheet
                            showFollowListBottomSheet(context, userId: userId, listType: FollowListType.followers);
                          },
                          child: Column(
                            children: [
                              Text(
                                followerCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Text('Followers', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        // Divider
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.white24,
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        // Followings
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(); // Close this sheet
                            showFollowListBottomSheet(context, userId: userId, listType: FollowListType.following);
                          },
                          child: Column(
                            children: [
                              Text(
                                followingCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Text('Following', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- Follow | Message Button Row ---
                    if (!isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            // Follow/Following Button
                            Expanded(
                              child: StreamBuilder<bool>(
                                stream: ProfileService.isFollowing(userId),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return ElevatedButton(onPressed: null, child: const Text('...'));
                                  }
                                  final bool isFollowing = snapshot.data ?? false;

                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFollowing ? Colors.grey.shade800 : Colors.pink,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () async {
                                      try {
                                        if (isFollowing) {
                                          await ProfileService.unfollowUser(userId);
                                        } else {
                                          await ProfileService.followUser(userId);
                                        }
                                      } catch (e) {
                                        debugPrint('Error following/unfollowing user: $e');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    },
                                    child: Text(isFollowing ? 'Following' : 'Follow'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Message Button
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();

                                  context.push(
                                    Routes.chat.path,
                                    extra: {'peerId': userId, 'peerName': userName, 'peerAvatar': userPicture ?? ""},
                                  );
                                },
                                child: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // --- Co-Host Actions (Host Only) ---
                    if (!isCurrentUser && isCurrentUserTheHost && roomId != null && (isSeated || isCoHost))
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCoHost ? Colors.red.shade700 : Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed: () async {
                              try {
                                if (isCoHost) {
                                  await RoomService.removeCoHost(roomId!, userId);
                                } else {
                                  await RoomService.promoteToCoHost(roomId!, userId);
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$userName is ${isCoHost ? 'no longer' : 'now'} a Co-Host!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                                }
                              }
                            },
                            icon: Icon(isCoHost ? Icons.star_outline_rounded : Icons.star_border_rounded),
                            label: Text(
                              isCoHost ? 'Remove Co-Host' : 'Make Co-Host',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    // Add bottom padding if the buttons are visible
                    if (!isCurrentUser) const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Top-level function to show the profile info bottom sheet.
void showProfileInfoBottomSheet(
  BuildContext context, {
  required String userId,
  String? hostId,
  String? roomId,
  bool isSeated = false,
  bool isCoHost = false,
}) {
  // Record the profile visit to Firestore
  _recordProfileVisit(userId);

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return ProfileInfoBottomSheet(
        userId: userId,
        hostId: hostId,
        roomId: roomId,
        isSeated: isSeated,
        isCoHost: isCoHost,
      );
    },
  );
}

/// Helper function to save a profile visit
Future<void> _recordProfileVisit(String visitedUserId) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Don't record a visit if the user isn't logged in or if they are visiting their own profile
    if (currentUser == null || currentUser.uid == visitedUserId) return;

    final visitorsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(visitedUserId)
        .collection('visitors')
        .doc(currentUser.uid);

    await visitorsRef.set({'visitorId': currentUser.uid, 'visitedAt': FieldValue.serverTimestamp()});
  } catch (e) {
    debugPrint('Error recording profile visit: $e');
  }
}
