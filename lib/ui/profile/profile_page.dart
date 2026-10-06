import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';

import 'package:go_router/go_router.dart';

// Firebase Imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get_it/get_it.dart';

import '../../data/local/secure_storage/secure_storage.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../data/remote/firebase/profile_services.dart';
import '../recharge/recharge_diamonds_page.dart';
import '../../data/remote/firebase/level_service.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

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
      backgroundColor: const Color(0xFF090614),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF090614),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF1E1430),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF2A8D).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A8D).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo/pigo live.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.live_tv,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(Routes.inbox.path),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18102B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2C194C), width: 1),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFFFFD166),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push(Routes.packageStore.path),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18102B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2C194C), width: 1),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD166),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push(Routes.status.path),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18102B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF2A8D).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_box_outlined,
                            color: Color(0xFFFF2A8D),
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Posts',
                            style: TextStyle(
                              color: Color(0xFFFF2A8D),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _userId == null
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context).loginToSeeProfile,
                        style: const TextStyle(color: Colors.white),
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
                          return Center(
                            child: Text(
                              AppLocalizations.of(context).profileNotFound,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        // Handle Success State
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final uid = snapshot.data!.id;

                        final now = DateTime.now();
                        final level = getSentLevel(data['totalSent'] ?? 0);

                        return FutureBuilder<List<dynamic>>(
                          future: Future.wait([
                            ProfileService.getMonthlyGiftsReceived(
                              userId: uid,
                              year: now.year,
                              month: now.month,
                            ),
                            ProfileService.getHostingApplicationStatus(),
                            ProfileService.getAgencyApplicationStatus(),
                            ProfileService.getSystemTags(),
                            ProfileService.getLevelImageUrl(level),
                          ]),
                          builder: (context, snapshot) {
                            // Determine host/agency approval
                            bool isHost = false;
                            bool isAgency = false;
                            Map<String, dynamic> systemTags = {};
                            if (snapshot.hasData) {
                              final hostDoc =
                                  snapshot.data![1]
                                      as dynamic; // DocumentSnapshot
                              final agencyDoc = snapshot.data![2] as dynamic;
                              if (hostDoc.exists) {
                                final d =
                                    hostDoc.data() as Map<String, dynamic>;
                                isHost = d['status'] == 'approved';
                              }
                              if (agencyDoc.exists) {
                                final d =
                                    agencyDoc.data() as Map<String, dynamic>;
                                isAgency = d['status'] == 'active';
                              }
                              if (snapshot.data!.length > 3) {
                                systemTags = snapshot.data![3] as Map<String, dynamic>;
                              }
                              if (snapshot.data!.length > 4) {
                                systemTags['levelImageUrl'] = snapshot.data![4] as String?;
                              }
                            }

                            // Map Firestore data to our local UserProfile model
                            final userProfile = UserProfile(
                              name:
                                  data['displayName'] ??
                                  AppLocalizations.of(context).noName,
                              id: uid,
                              displayId: data['displayId'] ?? 'N/A',
                              country: data['country'] ?? 'N/A',
                              countryFlagEmoji: data['countryFlagEmoji'],
                              bio:
                                  data['bio'] ??
                                  AppLocalizations.of(context).noBio,
                              profileImage: data['photoUrl'] ?? '',
                              followers: (data['followerCount'] as num?)?.toInt() ?? 0,
                              following: (data['followingCount'] as num?)?.toInt() ?? 0,
                              diamonds: (data['diamonds'] as num?)?.toInt() ?? 0,
                              beans: (data['balance'] as num?)?.toInt() ?? 0,
                              isHost: isHost || data['isHost'] == true || data['ishost'] == true || data['role'] == 'host',
                              isAgency: isAgency || data['isAgency'] == true || data['isagency'] == true || data['role'] == 'agency',
                              gender: data['gender'] ?? '',
                              isReseller: data['isReseller'] == true || data['role'] == 'reseller',
                              totalReceived: (data['totalReceived'] as num?)?.toInt() ?? 0,
                              giftSendingLevel: level,
                              isModerator: ProfileService.checkIsModerator(data),
                              manualTags: (data['manualTags'] as List<dynamic>?)
                                      ?.map((e) => e.toString())
                                      .toList() ??
                                  [],
                            );

                            return FutureBuilder<int>(
                              future: ProfileService.getMutualsList(
                                userProfile.id,
                              ).then((l) => l.length),
                              builder: (context, mutualsSnapshot) {
                                final friendsCount =
                                    mutualsSnapshot.data ?? 0;
                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      _buildHeroProfileCard(
                                        userProfile: userProfile,
                                        userEmail: data['email'] ??
                                            FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.email,
                                        friendsCount: friendsCount,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildMenuList(context, userProfile),
                                      const SizedBox(height: 120),
                                    ],
                                  ),
                                );
                              },
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


  Widget _buildHeroProfileCard({
    required UserProfile userProfile,
    required String? userEmail,
    required int friendsCount,
  }) {
    final starCount = userProfile.beans >= 100000
        ? userProfile.beans ~/ 100000
        : (userProfile.giftSendingLevel * 3 + (userProfile.followers > 0 ? 5 : 1));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A0E4E),
            Color(0xFF260A3D),
            Color(0xFF140624),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8A2BE2).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A0E4E).withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- Top User Info Row ---
          Row(
            children: [
              // Avatar with VVIP Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF9D4EDD),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A8D).withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: (userProfile.profileImage.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: userProfile.profileImage,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF512DA8),
                                child: const Icon(Icons.person, color: Colors.white, size: 40),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF512DA8),
                              child: Center(
                                child: Text(
                                  userProfile.name.isNotEmpty
                                      ? userProfile.name[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  // VVIP / VIP Badge at bottom right of Avatar
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: Image.asset(
                      'assets/images/VVIP PNG.png',
                      height: 28,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/VIP PNG.png',
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.verified,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // User Details (Name, Subtitle, ID)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (userEmail != null && userEmail.isNotEmpty)
                          ? userEmail
                          : (userProfile.bio.isNotEmpty
                              ? userProfile.bio
                              : 'Pigo Live User'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: userProfile.displayId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ID copied!'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF5A189A),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${userProfile.displayId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Dark Stats Pill Card Inside Hero Card ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0C071A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF261540).withValues(alpha: 0.9),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Top Badges Row (Diamond, Star, Level)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Diamond Pill
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RechargeDiamondsPage()),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.diamond_rounded,
                            color: Color(0xFF00B4D8),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${userProfile.beans}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Star Pill
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD166),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$starCount',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Level Pill (L.V. 13)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A189A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'L.V. ${userProfile.giftSendingLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
                const SizedBox(height: 10),

                // Bottom Stats Row (Friends, Followers, Following)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Friends
                    GestureDetector(
                      onTap: _showFriendsBottomSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF48CAE4),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$friendsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Friends',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Followers
                    GestureDetector(
                      onTap: _showFollowersBottomSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF2A8D),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${userProfile.followers}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Followers',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Following
                    GestureDetector(
                      onTap: _showFollowingBottomSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFFFFB703),
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${userProfile.following}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Following',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF130C22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF251842).withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExchangeDialog(UserProfile userProfile) async {
    // Fetch dynamic exchange rate from Firestore
    double exchangeRatePct = 60.0; // fallback default
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('Commission_config')
          .get();
      if (configDoc.exists) {
        final raw = configDoc.data()?['exchangerate'];
        final parsed = double.tryParse(raw?.toString() ?? '');
        if (parsed != null) exchangeRatePct = parsed;
      }
    } catch (e) {
      debugPrint('Failed to fetch exchange rate: $e');
    }

    final TextEditingController amountController = TextEditingController();
    bool isExchanging = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final int parsedAmount = int.tryParse(amountController.text) ?? 0;
            final int receivedRechargeCoins = (parsedAmount * exchangeRatePct / 100).toInt();

            return AlertDialog(
              title: const Text('Exchange Coins'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Convert Earning Coins to Recharge Coins.\n\nAvailable Earnings: ${userProfile.diamonds} diamonds\nConversion Rate: ${exchangeRatePct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount to Exchange',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                  if (parsedAmount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'You will receive: $receivedRechargeCoins Recharge Coins',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isExchanging ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isExchanging
                      ? null
                      : () async {
                          if (parsedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount.')),
                            );
                            return;
                          }
                          if (parsedAmount > userProfile.diamonds) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Insufficient earning coins.')),
                            );
                            return;
                          }

                          setState(() => isExchanging = true);
                          try {
                            await ProfileService.exchangeDiamondsToBeans(parsedAmount);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Exchange successful!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Exchange failed: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => isExchanging = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A189A),
                  ),
                  child: isExchanging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Exchange', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNewCoinButton({
    required String title,
    IconData? icon,
    required int value,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B0B59), Color(0xFF1A052A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF1E7A).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF1E7A).withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  const Icon(Icons.diamond_rounded, size: 20, color: Color(0xFFFFD700)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (value >= 100000) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${value ~/ 100000}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, UserProfile userProfile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (userProfile.isReseller) ...[
            _buildMenuItemCard(
              icon: Icons.storefront_rounded,
              title: 'Reseller Hub',
              iconBgColor: const Color(0xFF162544),
              iconColor: const Color(0xFF2196F3),
              onTap: () => context.push(Routes.resellerHub.path),
            ),
          ],
          if (userProfile.isAgency) ...[
            _buildMenuItemCard(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Host Management',
              iconBgColor: const Color(0xFF381A16),
              iconColor: const Color(0xFFFF5722),
              onTap: () => context.push(Routes.hostManagement.path),
            ),
          ],

          // 1. Account (matching screenshot)
          _buildMenuItemCard(
            icon: Icons.manage_accounts_rounded,
            title: 'Account',
            iconBgColor: const Color(0xFF28133D),
            iconColor: const Color(0xFFC77DFF),
            onTap: () => context.push(Routes.editProfile.path),
          ),

          // 2. Block List: 0 (matching screenshot)
          _buildMenuItemCard(
            icon: Icons.person_off_rounded,
            title: 'Block List: 0',
            iconBgColor: const Color(0xFF380E23),
            iconColor: const Color(0xFFFF2A8D),
            onTap: () => _showBlockedUsersDialog(),
          ),

          // 3. History (matching screenshot)
          _buildMenuItemCard(
            icon: Icons.history_rounded,
            title: 'History',
            iconBgColor: const Color(0xFF0E1A38),
            iconColor: const Color(0xFF48CAE4),
            onTap: () => context.push(Routes.history.path),
          ),

          // 4. Withdraw (matching screenshot)
          _buildMenuItemCard(
            icon: Icons.monetization_on_rounded,
            title: 'Withdraw',
            iconBgColor: const Color(0xFF382B0E),
            iconColor: const Color(0xFFFFD166),
            onTap: () => context.push(Routes.withdrawPage.path),
          ),

          // 5. Store
          _buildMenuItemCard(
            icon: Icons.shopping_bag_rounded,
            title: 'Store',
            iconBgColor: const Color(0xFF0E3827),
            iconColor: const Color(0xFF2EC4B6),
            onTap: () => context.push(Routes.store.path),
          ),

          // 6. My Bag
          _buildMenuItemCard(
            icon: Icons.inventory_2_rounded,
            title: 'My Bag',
            iconBgColor: const Color(0xFF280E38),
            iconColor: const Color(0xFF9D4EDD),
            onTap: () => context.push(Routes.myBag.path),
          ),

          // 7. Royal Package
          _buildMenuItemCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Royal Package',
            iconBgColor: const Color(0xFF38280E),
            iconColor: const Color(0xFFFFB703),
            onTap: () => context.push(Routes.packageStore.path, extra: 'Royal Package'),
          ),

          // 8. Crown Package
          _buildMenuItemCard(
            icon: Icons.stars_rounded,
            title: 'Crown Package',
            iconBgColor: const Color(0xFF380E1E),
            iconColor: const Color(0xFFFF512F),
            onTap: () => context.push(Routes.packageStore.path, extra: 'Crown Package'),
          ),

          // 9. King Package
          _buildMenuItemCard(
            icon: Icons.diamond_rounded,
            title: 'King Package',
            iconBgColor: const Color(0xFF161638),
            iconColor: const Color(0xFF8F94FB),
            onTap: () => context.push(Routes.packageStore.path, extra: 'King Package'),
          ),

          // 10. Queen Package
          _buildMenuItemCard(
            icon: Icons.favorite_rounded,
            title: 'Queen Package',
            iconBgColor: const Color(0xFF300E38),
            iconColor: const Color(0xFFDA22FF),
            onTap: () => context.push(Routes.packageStore.path, extra: 'Queen Package'),
          ),

          // 11. Host Request
          _buildMenuItemCard(
            icon: Icons.headset_mic_rounded,
            title: 'Host Request',
            iconBgColor: const Color(0xFF0E2F38),
            iconColor: const Color(0xFF00B4D8),
            onTap: () => context.push(Routes.applyHosting.path),
          ),

          // 12. Share App
          _buildMenuItemCard(
            icon: Icons.share_rounded,
            title: 'Share App',
            iconBgColor: const Color(0xFF0E3832),
            iconColor: const Color(0xFF48CAE4),
            onTap: () => _shareApp(),
          ),

          // 13. Customer Support
          _buildMenuItemCard(
            icon: Icons.chat_bubble_rounded,
            title: 'Support',
            iconBgColor: const Color(0xFF112638),
            iconColor: const Color(0xFF4EA8DE),
            onTap: () => _showSupportDialog(),
          ),

          // 14. Privacy Policy
          _buildMenuItemCard(
            icon: Icons.shield_rounded,
            title: 'Privacy Policy',
            iconBgColor: const Color(0xFF1F1238),
            iconColor: const Color(0xFF7209B7),
            onTap: () => _showPrivacyPolicy(),
          ),

          // 15. Terms & Conditions
          _buildMenuItemCard(
            icon: Icons.description_rounded,
            title: 'Terms & Conditions',
            iconBgColor: const Color(0xFF261D38),
            iconColor: const Color(0xFF90E0EF),
            onTap: () => _showTermsConditions(),
          ),

          // 16. Logout
          _buildMenuItemCard(
            icon: Icons.logout_rounded,
            title: 'Logout',
            iconBgColor: const Color(0xFF380E14),
            iconColor: const Color(0xFFFF4D4D),
            onTap: () => _confirmLogout(),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeDiamondsCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.rechargeDiamonds.path),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A189A), Color(0xFFFF4081)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A189A).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFF5A189A), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Recharge Diamonds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMulticolorMenuItem(_PinkMenuItemData item) {
    final gradient = item.gradient ?? const [Color(0xFF5A189A), Color(0xFFFF4081)];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1542),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgencyCardGroup(List<_PinkMenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            _buildAgencyMenuItem(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildAgencyMenuItem(_PinkMenuItemData item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(item.icon, color: const Color(0xFF131A2A), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Colors.amber, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildResellerCardGroup(List<_PinkMenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            _buildResellerMenuItem(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildResellerMenuItem(_PinkMenuItemData item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C6FF).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFF00E5FF), size: 18),
          ],
        ),
      ),
    );
  }

  void _showDevelopmentSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'ডেভেলপমেন্ট এর কাজ চলছে...',
          style: TextStyle(fontFamily: 'HindSiliguri'),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }


  Widget _buildMenuItem({
    required String title,
    required VoidCallback onTap,
    List<Color> colors = const [Color(0xFF444444), Color(0xFF666666)],
    Color borderColor = const Color(0xFF888888),
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _showBlockedUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block List'),
        content: const Text('You have no blocked users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    Share.share(
      'Download and join Pigo Live now!\nhttps://play.google.com/store/apps/details?id=com.pigobdlive.app',
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer Support'),
        content: const Text('For assistance, contact support@jslive.com'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'We value your privacy. Your personal information is encrypted and securely stored. We never sell your personal data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Pigo Live, you agree to our terms of service, community guidelines, and content policies.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              await GetIt.I<SecureStorage>().logout();
              if (context.mounted) {
                context.go(Routes.login.path);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
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
      builder: (context) => UserListBottomSheet(
        title: AppLocalizations.of(context).friends,
        userId: _userId!,
        listType: UserListType.friends,
      ),
    );
  }

  void _showFollowersBottomSheet() {
    if (_userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserListBottomSheet(
        title: AppLocalizations.of(context).followers,
        userId: _userId!,
        listType: UserListType.followers,
      ),
    );
  }

  void _showFollowingBottomSheet() {
    if (_userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserListBottomSheet(
        title: AppLocalizations.of(context).following,
        userId: _userId!,
        listType: UserListType.following,
      ),
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

  /// True when hosting application status == 'approved'
  final bool isHost;

  /// True when agency application status == 'active'
  final bool isAgency;
  final String gender;
  final bool isReseller;
  final bool isModerator;
  final int totalReceived;
  final List<String> manualTags;

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
    this.isHost = false,
    this.isAgency = false,
    this.gender = '',
    this.isReseller = false,
    this.isModerator = false,
    this.totalReceived = 0,
    this.manualTags = const [],
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
  return LevelService.getSentLevel(totalSent);
}

class _PinkMenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final List<Color>? gradient;

  _PinkMenuItemData({
    required this.icon,
    required this.title,
    required this.onTap,
    this.gradient,
  });
}
