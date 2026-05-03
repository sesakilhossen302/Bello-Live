import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

// Firebase Imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../core/widgets/auto_scroll_text.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

// Make sure this import path matches where your ProfileInfoBottomSheet is located
import '../live_streaming/bottomsheets/profile_info_bottomsheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _buildHeaderIconButton(
                        icon: CupertinoIcons.pencil,
                        onTap: () => context.push(Routes.editProfile.path),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderIconButton(
                        icon: CupertinoIcons.settings,
                        onTap: () => context.push(Routes.settingsPage.path),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _userId == null
                  ? const Center(
                      child: Text(
                        'Please log in to see your profile.',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: ProfileService.getUserProfileStream(_userId!),
                      builder: (context, snapshot) {
                        // Handle Loading State
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.pink,
                            ),
                          );
                        }

                        // Handle Error State
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.red.shade300),
                            ),
                          );
                        }

                        // Handle No Data State
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                            child: Text(
                              'Profile not found.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        // Handle Success State
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final uid = snapshot.data!.id;

                        final now = DateTime.now();

                        return FutureBuilder<int>(
                          future: ProfileService.getMonthlyGiftsReceived(
                            userId: uid,
                            year: now.year,
                            month: now.month,
                          ),
                          builder: (context, diamondSnapshot) {
                            final int monthlyDiamonds =
                                diamondSnapshot.data ?? 0;

                            // Map Firestore data to our local UserProfile model
                            final userProfile = UserProfile(
                              name: data['displayName'] ?? 'No Name',
                              id: uid,
                              displayId: data['displayId'] ?? 'N/A',
                              country: data['country'] ?? 'N/A',
                              countryFlagEmoji: data['countryFlagEmoji'],
                              bio: data['bio'] ?? 'No bio yet.',
                              profileImage: data['photoUrl'] ?? '',
                              followers: data['followerCount'] ?? 0,
                              following: data['followingCount'] ?? 0,
                              diamonds: monthlyDiamonds,
                              beans: data['balance'] ?? 0,
                              giftSendingLevel: getSentLevel(
                                data['totalSent'] ?? 0,
                              ),
                            );

                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  _buildTopAvatar(userProfile),
                                  const SizedBox(height: 20),
                                  _buildUserInfoCard(userProfile),
                                  const SizedBox(height: 10),
                                  _buildLocationSection(userProfile),
                                  const SizedBox(height: 20),
                                  FutureBuilder<int>(
                                    future: ProfileService.getMutualsList(userProfile.id).then((l) => l.length),
                                    builder: (context, mutualsSnapshot) {
                                      final friendsCount = mutualsSnapshot.data ?? 0;
                                      return _buildStatistics(userProfile, friendsCount);
                                    },
                                  ),
                                  const SizedBox(height: 15),
                                  _buildDiamondCard(userProfile),
                                  const SizedBox(height: 15),
                                  _buildMenuList(context),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.barColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildTopAvatar(UserProfile userProfile) {
    final profileImageUrl = userProfile.profileImage;
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7E57C2), // Purple color from screenshot
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: (profileImageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Text(
                          'F',
                          style: TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'F',
                        style: TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ),
          Positioned(
            width: 160 * 1.3,
            height: 160 * 1.3,
            child: IgnorePointer(child: ActiveFrameWidget(userId: userProfile.id, size: 160 * 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(UserProfile userProfile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.barColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFF7E57C2),
            backgroundImage: userProfile.profileImage.isNotEmpty ? NetworkImage(userProfile.profileImage) : null,
            child: userProfile.profileImage.isEmpty
                ? const Text('F', style: TextStyle(color: Colors.white, fontSize: 24))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProfile.name,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${userProfile.displayId}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, color: Colors.white70, size: 24),
                    const SizedBox(width: 4),
                    Text(
                      '${userProfile.giftSendingLevel}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lv ${userProfile.giftSendingLevel}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(UserProfile userProfile) {
    return Column(
      children: [
        Text(
          userProfile.country,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.barColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userProfile.countryFlagEmoji != null) ...[
                Text(userProfile.countryFlagEmoji!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Text(userProfile.country, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(UserProfile userProfile, int friendsCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: AppColors.barColor.withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(friendsCount.toString(), 'Friends', onTap: _showFriendsBottomSheet),
          _buildVerticalDivider(),
          _buildStatItem(userProfile.followers.toString(), 'Followers', onTap: _showFollowersBottomSheet),
          _buildVerticalDivider(),
          _buildStatItem(userProfile.following.toString(), 'Following', onTap: _showFollowingBottomSheet),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildDiamondCard(UserProfile userProfile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: AppColors.barColor.withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.diamond_outlined, color: Colors.white70, size: 28),
          const SizedBox(width: 12),
          Text(
            userProfile.diamonds.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }


  Widget _buildMenuList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.card_giftcard,
            iconColor: Colors.blueAccent,
            title: 'Claim 10,000 coins',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: Colors.orange,
            title: 'Top-up',
            onTap: () => context.push(Routes.topUp.path),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.trending_up,
            iconColor: Colors.redAccent,
            title: 'Earning',
            onTap: () => context.push(Routes.earnings.path),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.stars,
            iconColor: Colors.amber,
            title: 'VIP',
            onTap: () => context.push(Routes.vip.path),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.store,
            iconColor: Colors.cyan,
            title: 'Store',
            onTap: () => context.push(Routes.store.path),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.palette,
            iconColor: Colors.deepPurpleAccent,
            title: 'Theme',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.shopping_bag_outlined,
            iconColor: Colors.orangeAccent,
            title: 'My Bag',
            onTap: () => context.push(Routes.myBag.path),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.barColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  // ========== BOTTOM SHEET METHODS ==========

  void _showFriendsBottomSheet() {
    if (_userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserListBottomSheet(title: 'Friends', userId: _userId!, listType: UserListType.friends),
    );
  }

  void _showFollowersBottomSheet() {
    if (_userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserListBottomSheet(title: 'Followers', userId: _userId!, listType: UserListType.followers),
    );
  }

  void _showFollowingBottomSheet() {
    if (_userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserListBottomSheet(title: 'Following', userId: _userId!, listType: UserListType.following),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}

class ProfileButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const ProfileButton({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            debugPrint('$title tapped');
          },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: AppColors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data Models
class UserProfile {
  final String name;
  final String id;
  final String displayId;
  final String country;
  final String? countryFlagEmoji;
  final String bio;
  final String profileImage;
  final int followers;
  final int following;
  final int diamonds;
  final int beans;
  final int giftSendingLevel;

  UserProfile({
    required this.name,
    required this.id,
    required this.displayId,
    required this.country,
    this.countryFlagEmoji,
    required this.bio,
    required this.profileImage,
    required this.followers,
    required this.following,
    required this.diamonds,
    required this.beans,
    this.giftSendingLevel = 1,
  });
}

// ========== USER LIST BOTTOM SHEET ==========

enum UserListType { friends, followers, following }

class UserListBottomSheet extends StatefulWidget {
  final String title;
  final String userId;
  final UserListType listType;

  const UserListBottomSheet({
    super.key,
    required this.title,
    required this.userId,
    required this.listType,
  });

  @override
  State<UserListBottomSheet> createState() => _UserListBottomSheetState();
}

class _UserListBottomSheetState extends State<UserListBottomSheet> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  List<SimpleUser> _users = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      List<SimpleUser> users;

      switch (widget.listType) {
        case UserListType.friends:
          users = await ProfileService.getMutualsList(widget.userId);
          break;
        case UserListType.followers:
          users = await ProfileService.getFollowersList(widget.userId);
          break;
        case UserListType.following:
          users = await ProfileService.getFollowingList(widget.userId);
          break;
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<RoomStatus?> _getUserRoomStatus(String userId) async {
    try {
      // Check in audio rooms (rooms)
      final audioRoomsSnapshot = await _database.ref('rooms').get();
      if (audioRoomsSnapshot.exists) {
        final rooms = audioRoomsSnapshot.value as Map<dynamic, dynamic>;

        for (final entry in rooms.entries) {
          final roomId = entry.key.toString();
          final roomData = entry.value as Map<dynamic, dynamic>;

          if (roomData['isActive'] == true) {
            final participants =
                roomData['room_participants'] as Map<dynamic, dynamic>?;
            if (participants != null && participants.containsKey(userId)) {
              final participant = participants[userId] as Map<dynamic, dynamic>;
              final isHost = roomData['hostId'] == userId;

              return RoomStatus(
                roomId: roomId,
                isLiveStream: false,
                isVideo: false,
                isHost: isHost,
                isCoHost: participant['isCoHost'] ?? false,
                isOnline: participant['isOnline'] ?? false,
              );
            }
          }
        }
      }

      // Check in live streams (live_streams)
      final liveStreamsSnapshot = await _database.ref('live_streams').get();
      if (liveStreamsSnapshot.exists) {
        final streams = liveStreamsSnapshot.value as Map<dynamic, dynamic>;

        for (final entry in streams.entries) {
          final roomId = entry.key.toString();
          final roomData = entry.value as Map<dynamic, dynamic>;

          if (roomData['isActive'] == true) {
            final participants =
                roomData['participants'] as Map<dynamic, dynamic>?;
            if (participants != null && participants.containsKey(userId)) {
              final participant = participants[userId] as Map<dynamic, dynamic>;
              final isHost = roomData['hostId'] == userId;

              return RoomStatus(
                roomId: roomId,
                isLiveStream: true,
                isVideo: true,
                isHost: isHost,
                isCoHost: false,
                isOnline: participant['isOnline'] ?? false,
              );
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error checking room status: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF2d1b2b), // Match your app's bottom sheet background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // User List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.pink),
                  )
                : _error.isNotEmpty
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text(
                      'No ${widget.title.toLowerCase()} yet',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return FutureBuilder<RoomStatus?>(
                        future: _getUserRoomStatus(user.id),
                        builder: (context, snapshot) {
                          final roomStatus = snapshot.data;
                          return UserListTile(
                            user: user,
                            roomStatus: roomStatus,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ========== ROOM STATUS MODEL ==========

class RoomStatus {
  final String roomId;
  final bool isLiveStream;
  final bool isVideo;
  final bool isHost;
  final bool isCoHost;
  final bool isOnline;

  RoomStatus({
    required this.roomId,
    required this.isLiveStream,
    required this.isVideo,
    required this.isHost,
    required this.isCoHost,
    required this.isOnline,
  });

  bool get isInRoom => isOnline;
}

// ========== USER LIST TILE ==========

class UserListTile extends StatelessWidget {
  final SimpleUser user;
  final RoomStatus? roomStatus;

  const UserListTile({super.key, required this.user, this.roomStatus});

  void _joinRoom(BuildContext context) {
    if (roomStatus == null) return;

    // Close the bottom sheet first
    Navigator.pop(context);

    // Navigate based on room type
    if (roomStatus!.isLiveStream) {
      context.push(
        Routes.liveStream.path,
        extra: {"roomId": roomStatus!.roomId, "isHost": false},
      );
    } else if (!roomStatus!.isVideo) {
      context.push(
        Routes.audioRoom.path,
        extra: {"roomId": roomStatus!.roomId, "isHost": false},
      );
    } else {
      context.push(
        Routes.videoRoom.path,
        extra: {"roomId": roomStatus!.roomId, "isHost": false},
      );
    }
  }

  // Open the short ProfileInfoBottomSheet
  void _showProfile(BuildContext context) {
    showProfileInfoBottomSheet(context, userId: user.id);
  }

  String _getRoomTypeText() {
    if (roomStatus == null) return '';

    if (roomStatus!.isHost) {
      if (roomStatus!.isLiveStream) {
        return 'Hosting Live Stream';
      } else if (roomStatus!.isVideo) {
        return 'Hosting Video Room';
      } else {
        return 'Hosting Audio Room';
      }
    } else if (roomStatus!.isCoHost) {
      return 'Co-hosting';
    } else {
      if (roomStatus!.isLiveStream) {
        return 'In Live Stream';
      } else if (roomStatus!.isVideo) {
        return 'In Video Room';
      } else {
        return 'In Audio Room';
      }
    }
  }

  IconData _getRoomIcon() {
    if (roomStatus == null) return Icons.mic;

    if (roomStatus!.isLiveStream || roomStatus!.isVideo) {
      return Icons.videocam;
    } else {
      return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInRoom = roomStatus?.isInRoom ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isInRoom
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.pink.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Tappable Area for Profile Info (Avatar + Name)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showProfile(context),
              child: Row(
                children: [
                  // Profile Picture with Live Indicator
                  SizedBox(
                    width: 56, // 28 * 2
                    height: 56,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey,
                          backgroundImage:
                              user.pictureUrl != null &&
                                  user.pictureUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(user.pictureUrl!)
                              : null,
                          child:
                              user.pictureUrl == null ||
                                  user.pictureUrl!.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        // Overlay the Frame (56 * 1.3 = 72.8)
                        Positioned(
                          width: 72.8,
                          height: 72.8,
                          child: IgnorePointer(
                            child: ActiveFrameWidget(
                              userId: user.id,
                              size: 72.8,
                            ),
                          ),
                        ),
                        if (isInRoom)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isInRoom) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _getRoomIcon(),
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _getRoomTypeText(),
                                  style: TextStyle(
                                    color: Colors.green.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Join Button
          if (isInRoom)
            GestureDetector(
              onTap: () => _joinRoom(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.pinkLight, AppColors.pinkDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== HELPER FUNCTIONS ==========

int getSentLevel(int totalSent) {
  // Catch negative numbers just in case
  if (totalSent < 0) return 0;

  // The array index exactly matches your desired level
  // Index 0 (< 50k) = Level 0
  // Index 1 (< 150k) = Level 1
  // etc...
  const List<int> thresholds = [
    50000,
    150000,
    300000,
    500000,
    1000000,
    2000000,
    4000000,
    6000000,
    10000000,
    15000000,
    // Indices 0-9
    20000000,
    25000000,
    35000000,
    50000000,
    80000000,
    110000000,
    140000000,
    170000000,
    205000000,
    240000000,
    // Indices 10-19
    275000000,
    310000000,
    345000000,
    385000000,
    425000000,
    465000000,
    505000000,
    545000000,
    595000000,
    645000000,
    // Indices 20-29
    695000000,
    745000000,
    795000000,
    855000000,
    915000000,
    975000000,
    1030000000,
    1090000000,
    1160000000,
    1230000000,
    // Indices 30-39
    1300000000,
    1370000000,
    1440000000,
    1520000000,
    1600000000,
    1680000000,
    1760000000,
    1840000000,
    1930000000,
    2020000000,
    // Indices 40-49
    2110000000,
    2200000000,
    2290000000,
    2390000000,
    2490000000,
    2590000000,
    2690000000,
    2790000000,
    2940000000,
    3090000000,
    // Indices 50-59
    3240000000,
    3390000000,
    3540000000,
    3740000000,
    3940000000,
    4140000000,
    4340000000,
    4540000000,
    4790000000,
    5040000000,
    // Indices 60-69
    5290000000,
    5540000000,
    5790000000,
    6090000000,
    6390000000,
    6690000000,
    6990000000,
    7290000000,
    7690000000,
    8090000000,
    // Indices 70-79
    8490000000,
    8890000000,
    9290000000,
    9790000000,
    10290000000,
    10790000000,
    11290000000,
    11790000000,
    12390000000,
    12990000000,
    // Indices 80-89
    13590000000,
    14190000000,
    14790000000,
    15490000000,
    16190000000,
    16890000000,
    17590000000,
    18290000000,
    19290000000,
    20290000000,
    // Indices 90-99
  ];

  for (int i = 0; i < thresholds.length; i++) {
    if (totalSent < thresholds[i]) {
      return i;
    }
  }

  // If they somehow send more than 20,290,000,000, cap them at 100
  return 100;
}
