import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/active_frame_widget.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../data/remote/firebase/room_services.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../../../navigation/routes.dart';
import '../../profile/profile_page.dart';
import 'follow_list_bottomsheet.dart';
import 'host_actions_bottomsheet.dart';
import 'report_user_bottomsheet.dart';

/// A bottom sheet that displays detailed info about a user.
class ProfileInfoBottomSheet extends StatefulWidget {
  final String userId;
  final String? hostId;
  final String? roomId;
  final bool isSeated;
  final bool isCoHost;
  final ScaffoldMessengerState? scaffoldMessenger;
  final bool isCurrentUserAdmin;
  final bool isCurrentUserModerator;

  const ProfileInfoBottomSheet({
    super.key,
    required this.userId,
    this.hostId,
    this.roomId,
    this.isSeated = false,
    this.isCoHost = false,
    this.scaffoldMessenger,
    this.isCurrentUserAdmin = false,
    this.isCurrentUserModerator = false,
  });

  @override
  State<ProfileInfoBottomSheet> createState() => _ProfileInfoBottomSheetState();
}

class _ProfileInfoBottomSheetState extends State<ProfileInfoBottomSheet> {
  late Future<Map<String, dynamic>> _tagsFuture;
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _tagsFuture = ProfileService.getSystemTags();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (widget.isCurrentUserModerator || widget.isCurrentUserAdmin) {
      _isModerator = true;
    } else if (currentUserId != null) {
      ProfileService.isUserModerator(currentUserId).then((val) {
        if (mounted && val) {
          setState(() => _isModerator = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // --- UPDATED LOGIC (Null-safe) ---
    final bool isHost = widget.hostId != null && widget.userId == widget.hostId;
    final bool isCurrentUser = widget.userId == currentUserId;
    final bool isCurrentUserTheHost = widget.hostId != null && currentUserId == widget.hostId;

    return StreamBuilder<DocumentSnapshot>(
      stream: ProfileService.getUserProfileStream(widget.userId),
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
                          // I am the HOST OR ADMIN viewing another user AND we are actually inside a room
                          if ((isCurrentUserTheHost || widget.isCurrentUserAdmin) && widget.roomId != null)
                            IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close this sheet
                                showHostActionsBottomSheet(
                                  context,
                                  targetUserId: widget.userId,
                                  targetUserName: userName,
                                  roomId: widget.roomId!, // Safe to force unwrap here
                                );
                              },
                            )
                          // I am a standard USER viewing another user (or viewed from main Profile page)
                          else
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // Close this sheet
                                showReportUserBottomSheet(context, reportedUserId: widget.userId, reportedUserName: userName);
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
                            child: IgnorePointer(child: ActiveFrameWidget(userId: widget.userId, size: 130)),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // User ID - tap to copy
                            GestureDetector(
                              onTap: () {
                                final text = data['displayId']?.toString() ?? 'N/A';
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('ID $text copied!')),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ID: ${data['displayId']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.copy, color: Colors.white70, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Balance/Coins count
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.cyan.shade600,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.diamond_outlined, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${data['balance'] ?? 0}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  if ((data['balance'] ?? 0) >= 100000) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${(data['balance'] ?? 0) ~/ 100000}',
                                      style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // --- Badges using FutureBuilder ---
                    FutureBuilder<Map<String, dynamic>>(
                      future: _tagsFuture,
                      builder: (context, tagsSnapshot) {
                        final systemTags = tagsSnapshot.data ?? {};
                        final gender = data['gender'] ?? '';
                        final country = data['country'] ?? '';
                        final countryFlagEmoji = data['countryFlagEmoji'];
                        final isReseller = data['isReseller'] == true || data['isreseler'] == true;
                        final isHost = data['hostId'] != null || data['isHost'] == true;
                        final cachedAgencyName = data['agencyName'] ?? data['agencyname'];
                        final agencyId = data['agencyId'] ?? data['agencyCode'] ?? data['agencycode'];
                        final List<dynamic> manualTags = data['manualTags'] ?? [];

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (gender.isNotEmpty && gender != 'N/A')
                              if (gender == 'Male' || gender == 'Female')
                                Image.asset(
                                  'assets/icons/$gender.png',
                                  height: 32,
                                  fit: BoxFit.contain,
                                )
                              else
                                _buildBadge(gender, Colors.blueAccent),
                            if (country.isNotEmpty && country != 'N/A')
                              if (countryFlagEmoji != null && countryFlagEmoji.isNotEmpty)
                                Text(
                                  countryFlagEmoji,
                                  style: const TextStyle(fontSize: 28),
                                )
                              else
                                _buildBadge(country, Colors.teal),
                            FutureBuilder<String?>(
                              future: ProfileService.getLevelImageUrl(level),
                              builder: (context, levelImgSnapshot) {
                                return _buildBadge('Level $level', Colors.pinkAccent, imageUrl: levelImgSnapshot.data);
                              },
                            ),
                            if (cachedAgencyName != null && cachedAgencyName.toString().isNotEmpty)
                              _buildBadge(cachedAgencyName.toString(), Colors.orange, imageUrl: systemTags['agency'] as String?)
                            else if (agencyId != null && agencyId.toString().isNotEmpty)
                              FutureBuilder<String?>(
                                future: ProfileService.getAgencyName(agencyId.toString()),
                                builder: (context, agencySnapshot) {
                                  final name = agencySnapshot.data;
                                  if (name != null && name.isNotEmpty) {
                                    return _buildBadge(name, Colors.orange, imageUrl: systemTags['agency'] as String?);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            if (isReseller)
                              _buildBadge('Coin Seller', Colors.amber.shade700, imageUrl: systemTags['coinseller'] as String?),
                            if (isHost)
                              _buildBadge('Host', Colors.deepPurpleAccent, imageUrl: systemTags['host'] as String?),
                            for (final tag in manualTags)
                              _buildBadge(tag.toString(), Colors.indigoAccent, imageUrl: systemTags[tag.toString()] as String?),
                          ],
                        );
                      },
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
                            showFollowListBottomSheet(context, userId: widget.userId, listType: FollowListType.followers);
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
                            showFollowListBottomSheet(context, userId: widget.userId, listType: FollowListType.following);
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
                                stream: ProfileService.isFollowing(widget.userId),
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
                                          await ProfileService.unfollowUser(widget.userId);
                                        } else {
                                          await ProfileService.followUser(widget.userId);
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
                                    extra: {'peerId': widget.userId, 'peerName': userName, 'peerAvatar': userPicture ?? ""},
                                  );
                                },
                                child: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // --- Co-Host Actions (Host Only) ---
                    if (!isCurrentUser && isCurrentUserTheHost && widget.roomId != null && (widget.isSeated || widget.isCoHost))
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isCoHost ? Colors.red.shade700 : Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed: () async {
                              try {
                                if (widget.isCoHost) {
                                  try { await RoomService.removeCoHost(widget.roomId!, widget.userId); } catch (_) {}
                                  try { await LiveStreamService.setCoHost(widget.roomId!, widget.userId, false); } catch (_) {}
                                } else {
                                  try { await RoomService.promoteToCoHost(widget.roomId!, widget.userId); } catch (_) {}
                                  try { await LiveStreamService.setCoHost(widget.roomId!, widget.userId, true); } catch (_) {}
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$userName is ${widget.isCoHost ? 'no longer' : 'now'} a Co-Host!')),
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
                            icon: Icon(widget.isCoHost ? Icons.star_outline_rounded : Icons.star_border_rounded),
                            label: Text(
                              widget.isCoHost ? 'Remove Co-Host' : 'Make Co-Host',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    // Add bottom padding if the buttons are visible
                    if (!isCurrentUser && (isCurrentUserTheHost || _isModerator) && widget.roomId != null && widget.isSeated)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed: () async {
                              try {
                                try {
                                  await RoomService.removeUserFromSeat(widget.roomId!, widget.userId);
                                } catch (_) {}
                                try {
                                  await LiveStreamService.removeUserFromSeat(widget.roomId!, widget.userId);
                                } catch (_) {}
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$userName has been removed from the seat.'),
                                      backgroundColor: Colors.green,
                                    ),
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
                            icon: const Icon(Icons.person_remove_rounded),
                            label: const Text(
                              'Kick from Seat',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      
                    if (!isCurrentUser && (isCurrentUserTheHost || widget.isCurrentUserAdmin) && widget.roomId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF673AB7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              showHostActionsBottomSheet(
                                context,
                                targetUserId: widget.userId,
                                targetUserName: userName,
                                roomId: widget.roomId!,
                              );
                            },
                            icon: const Icon(Icons.security, size: 20),
                            label: const Text(
                              'Manage Admin & Actions',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    if (isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push(Routes.editProfile.path);
                            },
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color textColor, {String? imageUrl}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: MediaQuery.of(context).size.width * 0.095, // Responsive and larger
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildTextBadge(text, textColor),
      );
    }
    return _buildTextBadge(text, textColor);
  }

  Widget _buildTextBadge(String text, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

void showProfileInfoBottomSheet(
  BuildContext context, {
  required String userId,
  String? hostId,
  String? roomId,
  bool isSeated = false,
  bool isCoHost = false,
  bool isCurrentUserAdmin = false,
  bool isCurrentUserModerator = false,
}) {
  // Record the profile visit to Firestore
  _recordProfileVisit(userId);

  // Capture the outer ScaffoldMessenger BEFORE the bottom sheet opens
  // so SnackBars work correctly from inside the modal.
  final messenger = ScaffoldMessenger.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (_) {
      return ProfileInfoBottomSheet(
        userId: userId,
        hostId: hostId,
        roomId: roomId,
        isSeated: isSeated,
        isCoHost: isCoHost,
        scaffoldMessenger: messenger,
        isCurrentUserAdmin: isCurrentUserAdmin,
        isCurrentUserModerator: isCurrentUserModerator,
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

