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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/profile_bg.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(CupertinoIcons.pencil, size: 28, color: AppColors.pink),
                      onPressed: () {
                        context.push(Routes.editProfile.path);
                      },
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.settings, size: 28, color: AppColors.pink),
                      onPressed: () {
                        context.push(Routes.settingsPage.path);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _userId == null
                    ? const Center(
                        child: Text('Please log in to see your profile.', style: TextStyle(color: Colors.white)),
                      )
                    : StreamBuilder<DocumentSnapshot>(
                        stream: ProfileService.getUserProfileStream(_userId!),
                        builder: (context, snapshot) {
                          // Handle Loading State
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: AppColors.pink));
                          }

                          // Handle Error State
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade300)),
                            );
                          }

                          // Handle No Data State
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Center(
                              child: Text('Profile not found.', style: TextStyle(color: Colors.white70)),
                            );
                          }

                          // Handle Success State
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final uid = snapshot.data!.id;

                          final now = DateTime.now();

                          return FutureBuilder<int>(
                            future: ProfileService.getMonthlyGiftsReceived(
                              userId: uid,
                              year: now.year,
                              month: now.month,
                            ),
                            builder: (context, diamondSnapshot) {
                              final int monthlyDiamonds = diamondSnapshot.data ?? 0;

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
                                giftSendingLevel: getSentLevel(data['totalSent'] ?? 0),
                              );

                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    _buildProfileSection(userProfile),
                                    const SizedBox(height: 30),
                                    FutureBuilder<List<SimpleUser>>(
                                      future: ProfileService.getMutualsList(userProfile.id),
                                      builder: (context, mutualsSnapshot) {
                                        if (mutualsSnapshot.connectionState == ConnectionState.waiting) {
                                          return _buildStatistics(userProfile, null); // Pass null for loading
                                        }
                                        final friendsCount = mutualsSnapshot.data?.length ?? 0;
                                        return _buildStatistics(userProfile, friendsCount);
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _buildAchievementChips(userProfile),
                                    const SizedBox(height: 30),
                                    _buildButtonsGrid(),
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
      ),
    );
  }

  Widget _buildProfileSection(UserProfile userProfile) {
    final profileImageUrl = userProfile.profileImage;

    Widget countryIndicator;
    if (userProfile.countryFlagEmoji != null && userProfile.countryFlagEmoji!.isNotEmpty) {
      countryIndicator = Text(userProfile.countryFlagEmoji!, style: const TextStyle(fontSize: 16));
    } else {
      countryIndicator = Icon(Icons.location_on_rounded, color: Colors.blue.shade300, size: 14);
    }

    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.pinkLight, AppColors.pinkDark, Colors.pink.shade400, AppColors.pink600],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10)),
                    BoxShadow(color: Colors.pink.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 0)),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: (profileImageUrl.isNotEmpty)
                      ? Image.network(
                          profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800]),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 70),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800]),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 70),
                        ),
                ),
              ),
              // Overlay the Frame (140 * 1.3 = 182)
              Positioned(
                width: 182,
                height: 182,
                child: IgnorePointer(child: ActiveFrameWidget(userId: userProfile.id, size: 182)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Name
        ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: [AppColors.pinkLight, AppColors.pinkDark]).createShader(bounds),
          child: AutoScrollText(
            text: userProfile.name,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 8),

        // Level, ID and Country
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Level Badge
            Image.asset(
              'assets/images/levels/rank_caifu_cf_${userProfile.giftSendingLevel}.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            const SizedBox(width: 8),

            // ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                'ID: ${userProfile.displayId}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Country
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  countryIndicator,
                  const SizedBox(width: 4),
                  Text(
                    userProfile.country,
                    style: TextStyle(color: Colors.blue.shade300, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            userProfile.bio,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontStyle: FontStyle.italic),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(UserProfile userProfile, int? friendsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Friends', friendsCount, Colors.cyan, onTap: _showFriendsBottomSheet),
              _buildVerticalDivider(),
              _buildStatItem('Followers', userProfile.followers, Colors.pink, onTap: _showFollowersBottomSheet),
              _buildVerticalDivider(),
              _buildStatItem('Following', userProfile.following, Colors.pink, onTap: _showFollowingBottomSheet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int? count, Color color, {VoidCallback? onTap}) {
    String displayCount = count == null ? '-' : _formatNumber(count);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: [color, color]).createShader(bounds),
            child: Text(
              displayCount,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.3), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildAchievementChips(UserProfile userProfile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAchievementChip(
          assetIcon: 'assets/icons/beans.svg',
          count: userProfile.beans,
          color: Colors.amber,
          label: 'Beans',
          onTap: () {
            context.push(Routes.topUp.path);
          },
        ),
        const SizedBox(width: 16),
        _buildAchievementChip(
          icon: Icons.diamond_outlined,
          count: userProfile.diamonds,
          color: Colors.cyan,
          label: 'Diamonds',
        ),
      ],
    );
  }

  Widget _buildAchievementChip({
    IconData? icon,
    String? assetIcon,
    required int count,
    required Color color,
    required String label,
    void Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon, color: color, size: 24),
                if (assetIcon != null) SvgPicture.asset(assetIcon, colorFilter: ColorFilter.mode(color, BlendMode.srcIn), width: 24),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatNumber(count),
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      label,
                      style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonsGrid() {
    final buttons = [
      ProfileButton(
        title: 'Top Up',
        icon: Icons.account_balance_wallet_rounded,
        onTap: () {
          context.push(Routes.topUp.path);
        },
      ),
      ProfileButton(
        title: 'Earnings',
        icon: Icons.trending_up_rounded,
        onTap: () {
          context.push(Routes.earnings.path);
        },
      ),
      ProfileButton(
        title: 'VIP',
        icon: Icons.diamond_outlined,
        onTap: () {
          context.push(Routes.vip.path);
        },
      ),
      ProfileButton(
        title: 'Store',
        icon: Icons.shopping_bag_rounded,
        onTap: () {
          context.push(Routes.store.path);
        },
      ),
      ProfileButton(
        title: 'My Bag',
        icon: Icons.shopping_basket_rounded,
        onTap: () {
          context.push(Routes.myBag.path);
        },
      ),
      ProfileButton(
        title: 'My Level',
        icon: Icons.military_tech_rounded,
        onTap: () {
          context.push(Routes.myLevel.path);
        },
      ),
      ProfileButton(
        title: 'Support',
        icon: Icons.support_agent_rounded,
        onTap: () {
          context.push(Routes.feedback.path);
        },
      ),
      ProfileButton(title: 'Blocked', icon: Icons.block_rounded),
      ProfileButton(
        title: 'My Invites',
        icon: Icons.group_add_rounded,
        onTap: () {
          context.push(Routes.myInvites.path);
        },
      ),
      ProfileButton(
        title: 'Profile Visitors',
        icon: Icons.visibility_rounded,
        onTap: () {
          context.push(Routes.visitors.path);
        },
      ),
      ProfileButton(
        title: 'Apply Hosting',
        icon: Icons.live_tv_rounded,
        onTap: () {
          context.push(Routes.applyHosting.path);
        },
      ),
      ProfileButton(
        title: 'Apply Agency',
        icon: Icons.business_rounded,
        onTap: () {
          context.push(Routes.applyAgency.path);
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: buttons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final button = buttons[index];
        return button;
      },
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

  const ProfileButton({super.key, required this.title, required this.icon, this.onTap});

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
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFF5E4710), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFCA9B34), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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

  const UserListBottomSheet({super.key, required this.title, required this.userId, required this.listType});

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
            final participants = roomData['room_participants'] as Map<dynamic, dynamic>?;
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
            final participants = roomData['participants'] as Map<dynamic, dynamic>?;
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
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
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                ? Center(child: CircularProgressIndicator(color: AppColors.pink))
                : _error.isNotEmpty
                ? Center(
                    child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                  )
                : _users.isEmpty
                ? Center(
                    child: Text('No ${widget.title.toLowerCase()} yet', style: const TextStyle(color: Colors.white70)),
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
                          return UserListTile(user: user, roomStatus: roomStatus);
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
      context.push(Routes.liveStream.path, extra: {"roomId": roomStatus!.roomId, "isHost": false});
    } else if (!roomStatus!.isVideo) {
      context.push(Routes.audioRoom.path, extra: {"roomId": roomStatus!.roomId, "isHost": false});
    } else {
      context.push(Routes.videoRoom.path, extra: {"roomId": roomStatus!.roomId, "isHost": false});
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
        border: Border.all(color: isInRoom ? Colors.green.withValues(alpha: 0.5) : Colors.pink.withValues(alpha: 0.3), width: 1),
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
                          backgroundImage: user.pictureUrl != null && user.pictureUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(user.pictureUrl!)
                              : null,
                          child: user.pictureUrl == null || user.pictureUrl!.isEmpty
                              ? const Icon(Icons.person, color: Colors.white, size: 28)
                              : null,
                        ),
                        // Overlay the Frame (56 * 1.3 = 72.8)
                        Positioned(
                          width: 72.8,
                          height: 72.8,
                          child: IgnorePointer(child: ActiveFrameWidget(userId: user.id, size: 72.8)),
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
                                border: Border.all(color: Colors.white, width: 2),
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
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isInRoom) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(_getRoomIcon(), color: Colors.green, size: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.pinkLight, AppColors.pinkDark]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
