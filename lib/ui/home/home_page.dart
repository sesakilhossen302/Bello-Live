import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:picture_live/ui/home/tabs/pk_tab.dart';
import 'package:picture_live/ui/home/widgets/card_widget.dart';
import 'package:picture_live/ui/home/widgets/carousal_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/home_banner_cache_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/cubits/app_cubit.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';
import 'home_cubit.dart';
import 'home_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {

    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    ProfileService.syncFollowingNotificationTopics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Exit App',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Do you really want to close the application?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit()..init(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<HomeCubit>();
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldExit = await _showExitConfirmationDialog();
              if (shouldExit) {
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              extendBodyBehindAppBar: false,
              backgroundColor: const Color(0xFF1A052A),
              appBar: _buildNewAppBar(context),
              body: Column(
                children: [
                  _buildTickerBanner(),
                  _buildFilterTabs(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPopularTab(cubit), // 0: All
                        _buildPopularTab(cubit, isVideo: true), // 1: Video
                        _buildPopularTab(cubit, isVideo: false), // 2: Audio
                        SingleChildScrollView(
                          child: _buildFresherGrid(cubit),
                        ), // 3: Following
                        PKTab(cubit: cubit), // 4: PK
                        _buildPartyTab(cubit), // 5: Party
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildNewAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B0B59), Color(0xFF1A052A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFF1E7A).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1E7A).withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
        elevation: 0,
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A052A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF1E7A),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1E7A).withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo/pigo live.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF1E7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Bello Live',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appSettings')
                .doc('notificationnotice')
                .snapshots(),
            builder: (context, snapshot) {
              int noticeCount = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data();
                final raw = data?['notification'] ?? data?['notices'];
                if (raw is List) {
                  noticeCount = raw.where((e) => e.toString().trim().isNotEmpty).length;
                }
              }

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                    if (noticeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            noticeCount > 99 ? '99+' : '$noticeCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => context.push(Routes.notificationNotice.path),
              );
            },
          ),
          GestureDetector(
            onTap: () => context.push(Routes.ranks.path),
            child: Container(
              margin: const EdgeInsets.only(right: 14, left: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF1E7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1E7A).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('noticetext').limit(1).snapshots(),
      builder: (context, snapshot) {
        String tickerText = 'Welcome To Bello Live ↔ Enjoy your best time with Bello Live ↔';
        
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('text') && data['text'].toString().isNotEmpty) {
            tickerText = data['text'] as String;
          }
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9D4EDD), Color(0xFF5A189A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFF1E7A).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.swap_horizontal_circle, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: ScrollingTickerText(
                  text: tickerText,
                  style: GoogleFonts.hindSiliguri(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs() {
    final activeIndex = _tabController.index;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPillTab(
              label: 'All',
              isSelected: activeIndex == 0,
              onTap: () => _tabController.animateTo(0),
            ),
            const SizedBox(width: 10),
            _buildPillTab(
              label: 'Video',
              icon: Icons.videocam_rounded,
              isSelected: activeIndex == 1,
              onTap: () => _tabController.animateTo(1),
            ),
            const SizedBox(width: 10),
            _buildPillTab(
              label: 'Audio',
              icon: Icons.mic_rounded,
              isSelected: activeIndex == 2,
              onTap: () => _tabController.animateTo(2),
            ),
            const SizedBox(width: 10),
            _buildPillTab(
              label: 'Following',
              icon: Icons.favorite_rounded,
              isSelected: activeIndex == 3,
              onTap: () => _tabController.animateTo(3),
            ),
            const SizedBox(width: 10),
            _buildPillTab(
              label: 'PK',
              iconText: 'PK',
              isSelected: activeIndex == 4,
              onTap: () => _tabController.animateTo(4),
            ),
            const SizedBox(width: 10),
            _buildPillTab(
              label: 'Party',
              icon: Icons.celebration_rounded,
              isSelected: activeIndex == 5,
              onTap: () => _tabController.animateTo(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillTab({
    required String label,
    IconData? icon,
    String? assetPath,
    String? iconText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color(0xFF5A189A);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath != null) ...[
              Image.asset(
                assetPath,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
            ] else if (iconText != null) ...[
              Text(
                iconText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlimPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A189A), Color(0xFF9D4EDD)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A189A).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🔥 VIP Live Bonus Extravaganza',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Recharge today & get up to 50% extra diamonds!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Claim',
              style: TextStyle(
                color: Color(0xFF5A189A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTab(HomeCubit cubit, {bool? isVideo}) {
    return StreamBuilder<List<StreamerModel>>(
      stream: cubit.allRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final allRooms = (snapshot.data ?? []).where((room) {
          if (isVideo == null) return true;
          return room.isVideo == isVideo;
        }).toList();

        if (allRooms.isEmpty) {
          return SingleChildScrollView(
            child: Column(
              children: [
                CarouselBanner(
                  aspectRatio: 1600 / 580,
                  imageUrls: BannerUrls.liveStreamingBanners,
                  autoPlayDuration: const Duration(seconds: 4),
                  onBannerTap: (index) {
                    debugPrint('Banner $index tapped');
                  },
                ),
                const AgencyCarouselSlider(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: .9,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const RoomSkeletonWidget();
                    },
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              CarouselBanner(
                aspectRatio: 1600 / 580,
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) {
                  debugPrint('Banner $index tapped');
                },
              ),
              const AgencyCarouselSlider(),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .9,
                  ),
                  itemCount: allRooms.length,
                  itemBuilder: (context, index) {
                    return AnimatedStreamerCard(streamer: allRooms[index]);
                  },
                ),
              ),
              const SizedBox(height: 140),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFresherGrid(HomeCubit cubit) {
    return StreamBuilder<List<StreamerModel>>(
      stream: cubit.freshersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Column(
            children: [
              CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) {
                  debugPrint('Banner $index tapped');
                },
              ),
              const SizedBox(height: 140),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) {
                  debugPrint('Banner $index tapped');
                },
              ),
              const SizedBox(height: 140),
              Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        }

        final freshers = snapshot.data ?? [];

        if (freshers.isEmpty) {
          return Column(
            children: [
              CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) {
                  debugPrint('Banner $index tapped');
                },
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .9,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return const RoomSkeletonWidget();
                  },
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            CarouselBanner(
              imageUrls: BannerUrls.liveStreamingBanners,
              autoPlayDuration: const Duration(seconds: 4),
              onBannerTap: (index) {
                debugPrint('Banner $index tapped');
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .9,
                ),
                itemCount: freshers.length,
                itemBuilder: (context, index) {
                  return AnimatedStreamerCard(streamer: freshers[index]);
                },
              ),
            ),
            const SizedBox(height: 140),
          ],
        );
      },
    );
  }

  Widget _buildPartyTab(HomeCubit cubit) {
    return StreamBuilder<List<StreamerModel>>(
      stream: cubit.audioRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final audioRooms = snapshot.data ?? [];

        if (audioRooms.isEmpty) {
          return SingleChildScrollView(
            child: Column(
              children: [
                CarouselBanner(
                  imageUrls: BannerUrls.liveStreamingBanners,
                  autoPlayDuration: const Duration(seconds: 4),
                  onBannerTap: (bannerIndex) {
                    debugPrint('Banner $bannerIndex tapped');
                  },
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: const SizedBox(
                        height: 120,
                        child: RoomSkeletonWidget(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 140),
          itemCount: audioRooms.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (bannerIndex) {
                  debugPrint('Banner $bannerIndex tapped');
                },
              );
            }

            final streamer = audioRooms[index - 1];
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () {
                  if (streamer.isLiveStream) {
                    context.push(
                      Routes.liveStream.path,
                      extra: {"roomId": streamer.id, "isHost": false},
                    );
                  } else if (!streamer.isVideo) {
                    context.push(
                      Routes.audioRoom.path,
                      extra: {"roomId": streamer.id, "isHost": false},
                    );
                  } else {
                    context.push(
                      Routes.videoRoom.path,
                      extra: {"roomId": streamer.id, "isHost": false},
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.black.withValues(alpha: 0.7),
                              AppColors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Container(
                        height: 120,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      streamer.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(1, 1),
                                            blurRadius: 3,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (streamer.bio.isNotEmpty)
                                    Text(
                                      streamer.bio,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w400,
                                        height: 1.3,
                                        shadows: const [
                                          Shadow(
                                            offset: Offset(0.5, 0.5),
                                            blurRadius: 2,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${streamer.viewCount}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: streamer.imageUrl != null
                                    ? Image.network(
                                        streamer.imageUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[800],
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  size: 40,
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showLanguageBottomSheet(AppCubit appCubit) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1418), // Dark dusty rose background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return BlocProvider.value(
          value: appCubit,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final List<Map<String, String>> languages = [
                {'name': 'English', 'code': 'en', 'native': 'English'},
                {'name': 'Hindi', 'code': 'hi', 'native': 'हिन्दी'},
                {'name': 'Bangla', 'code': 'bn', 'native': 'বাংলা'},
                {'name': 'Spanish', 'code': 'es', 'native': 'Español'},
                {'name': 'Urdu', 'code': 'ur', 'native': 'اردو'},
              ];
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).chooseLanguage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...languages.map((lang) {
                      final currentLocale = context
                          .read<AppCubit>()
                          .state
                          .locale;
                      final isSelected =
                          currentLocale.languageCode == lang['code'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            context.read<AppCubit>().changeLocale(
                              Locale(lang['code']!),
                            );
                            setModalState(() {});
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                if (context.mounted) Navigator.pop(context);
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(
                                        0xFFFFB6C1,
                                      ).withValues(alpha: 0.6)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white54,
                                  size: 22,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  lang['native']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 17,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFFFB6C1),
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRegionBottomSheet(HomeCubit homeCubit) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF1E1418), // Dark dusty rose background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return BlocProvider.value(
          value: homeCubit,
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              final cubit = context.read<HomeCubit>();
              String searchQuery = '';
              return StatefulBuilder(
                builder: (context, setModalState) {
                  // Get all countries that have live users, plus Global
                  final liveCountries = state.countryCounts.keys
                      .where((c) => c != 'Unknown')
                      .toList();

                  // Sort live countries by count descending
                  liveCountries.sort(
                    (a, b) => (state.countryCounts[b] ?? 0).compareTo(
                      state.countryCounts[a] ?? 0,
                    ),
                  );

                  List<Map<String, dynamic>> regions = [
                    {
                      'name': 'Global',
                      'count': state.countryCounts.values.fold(
                        0,
                        (sum, count) => sum + count,
                      ),
                    },
                    ...liveCountries.map(
                      (c) => {'name': c, 'count': state.countryCounts[c] ?? 0},
                    ),
                  ];

                  // Apply search filter
                  if (searchQuery.isNotEmpty) {
                    regions = regions
                        .where(
                          (r) => (r['name'] as String).toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
                  }

                  return Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).filterByCountry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search Bar
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    ).searchCountries,
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    setModalState(() {
                                      searchQuery = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: regions.length,
                            itemBuilder: (context, index) {
                              final reg = regions[index];
                              final regionName = reg['name'] as String;
                              final liveCount = reg['count'] as int;
                              final isSelected =
                                  regionName == state.selectedCountry;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () {
                                    cubit.setCountry(regionName);
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(
                                                0xFFFFB6C1,
                                              ).withValues(alpha: 0.6)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.public,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white54,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          regionName,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 17,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (liveCount != 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$liveCount ${AppLocalizations.of(context).liveSuffix}',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Color(0xFFFFB6C1),
                                              size: 22,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class StreamerModel {
  final String id;
  final String? hostId;
  final String name;
  final String? imageUrl;
  final String bio;
  final int viewCount;
  final bool isPremium;
  final bool isVideo;
  final bool isLocked;
  final bool isLiveStream;
  final String country;
  final String? packageBadgeUrl;
  final bool isHost;
  final bool isAgency;
  final bool isReseller;
  final bool isModerator;
  final bool hasPackage;
  final int packagePriority;

  const StreamerModel({
    required this.id,
    this.hostId,
    required this.name,
    this.imageUrl,
    required this.bio,
    required this.viewCount,
    this.isPremium = false,
    this.isVideo = true,
    this.isLocked = false,
    this.isLiveStream = false,
    this.country = 'Unknown',
    this.packageBadgeUrl,
    this.isHost = false,
    this.isAgency = false,
    this.isReseller = false,
    this.isModerator = false,
    this.hasPackage = false,
    this.packagePriority = 0,
  });
}

class ScrollingTickerText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ScrollingTickerText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<ScrollingTickerText> createState() => _ScrollingTickerTextState();
}

class _ScrollingTickerTextState extends State<ScrollingTickerText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    _setupAnimation();
    _animationController.addListener(_scroll);
  }

  @override
  void didUpdateWidget(ScrollingTickerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    // Calculate duration based on text length for a constant, smooth reading speed.
    // Slower speed: ~4 characters per second.
    final int durationSeconds = (widget.text.length / 4).ceil().clamp(15, 600);
    _animationController.duration = Duration(seconds: durationSeconds);
    if (_animationController.isAnimating) {
      _animationController.repeat();
    } else {
      _animationController.repeat();
    }
  }

  void _scroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        final currentScroll = _animationController.value * maxScroll;
        _scrollController.jumpTo(currentScroll);
      }
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_scroll);
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 40),
          Text(widget.text, style: widget.style),
          const SizedBox(width: 40),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}

class AgencyCarouselSlider extends StatefulWidget {
  const AgencyCarouselSlider({super.key});

  @override
  State<AgencyCarouselSlider> createState() => _AgencyCarouselSliderState();
}

class _AgencyCarouselSliderState extends State<AgencyCarouselSlider> {
  late PageController _pageController;
  Timer? _timer;
  List<AgencyModel> _agencies = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92, initialPage: 1000);
    // Instant frame-0 loading from in-memory cache
    _agencies = List.from(HomeBannerCacheService.agencies);

    HomeBannerCacheService.agencyNotifier.addListener(_onAgenciesUpdated);

    if (_agencies.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startAutoPlay();
      });
    }
  }

  void _onAgenciesUpdated() {
    if (!mounted) return;
    final newAgencies = HomeBannerCacheService.agencies;
    setState(() {
      _agencies = List.from(newAgencies);
    });

    if (_agencies.length > 1 && _timer == null) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && _agencies.length > 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    HomeBannerCacheService.agencyNotifier.removeListener(_onAgenciesUpdated);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildRankBadge(String topRank) {
    final rankNum = int.tryParse(topRank.replaceAll(RegExp(r'[^0-9]'), '')) ?? 99;

    Color badgeColor;
    Color textColor;
    String icon;

    if (rankNum == 1) {
      badgeColor = const Color(0xFFFFD700);
      textColor = const Color(0xFF7A5800);
      icon = '🏆';
    } else if (rankNum == 2) {
      badgeColor = const Color(0xFFC0C0C0);
      textColor = const Color(0xFF404040);
      icon = '🥈';
    } else if (rankNum == 3) {
      badgeColor = const Color(0xFFCD7F32);
      textColor = const Color(0xFF4A2800);
      icon = '🥉';
    } else {
      badgeColor = Colors.black38;
      textColor = Colors.white;
      icon = '#';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(
            'Top $rankNum',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_agencies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 92,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          final agency = _agencies[index % _agencies.length];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: agency.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: agency.cardColor.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.white24,
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: agency.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (context, url) => Container(
                        color: Colors.white24,
                        alignment: Alignment.center,
                      ),
                      errorWidget: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white24,
                          alignment: Alignment.center,
                          child: Text(
                            agency.name.isNotEmpty ? agency.name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              agency.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildRankBadge(agency.topRank),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Agency Code: ${agency.code}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hosts: ${agency.hosts}  •  Diamonds: ${agency.diamonds}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RoomSkeletonWidget extends StatelessWidget {
  const RoomSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 10,
            child: Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

