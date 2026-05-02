import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../data/remote/firebase/profile_services.dart';

class RanksPage extends StatefulWidget {
  const RanksPage({super.key});

  @override
  State<RanksPage> createState() => _RanksPageState();
}

class _RanksPageState extends State<RanksPage> with TickerProviderStateMixin {
  late TabController _categoryController;
  late TabController _periodController;

  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(length: 3, vsync: this, initialIndex: 1); // Added Gifter
    _periodController = TabController(length: 3, vsync: this, initialIndex: 1);

    _categoryController.addListener(_handleTabSelection);
    _periodController.addListener(_handleTabSelection);

    _loadLeaderboard();
  }

  void _handleTabSelection() {
    if ((_categoryController.indexIsChanging || _periodController.indexIsChanging) == false) {
      _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String period = _periodController.index == 0
          ? 'daily'
          : _periodController.index == 1
          ? 'weekly'
          : 'monthly';

      List<LeaderboardUser> data;

      if (_categoryController.index == 1) {
        data = await ProfileService.getTopHosts(period: period, limit: 10);
      } else if (_categoryController.index == 2) {
        data = await ProfileService.getTopGifters(period: period, limit: 10);
      } else {
        data = []; // Agency is coming soon
      }

      if (mounted) {
        setState(() {
          _leaderboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a0a1e), Color(0xFF2d1b2b), Color(0xFF1a0a1e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildCategoryTabs(),
              const SizedBox(height: 10),
              _buildPeriodTabs(),
              Expanded(
                child: _categoryController.index == 0
                    ? _buildComingSoon()
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                    : _leaderboardData.isEmpty
                    ? _buildEmptyState()
                    : _buildRankContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Ranks',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
      ),
      child: TabBar(
        controller: _categoryController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF1168), Color(0xFFD81B60)]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Agency'),
          Tab(text: 'Host'),
          Tab(text: 'Gifter'),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
      ),
      child: TabBar(
        controller: _periodController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF1168), Color(0xFFD81B60)]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'Weeks'),
          Tab(text: 'Month'),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upcoming_outlined, size: 80, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text(
            'Coming Soon',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Agency rankings will be available soon',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 80, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text(
            'No rankings yet',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRankContent() {
    final topThree = _leaderboardData.take(3).toList();
    final restUsers = _leaderboardData.skip(3).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (topThree.isNotEmpty) _buildPodium(topThree),
          const SizedBox(height: 30),
          if (restUsers.isNotEmpty) _buildRankList(restUsers),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardUser> topThree) {
    final firstPlace = topThree.isNotEmpty ? topThree[0] : null;
    final secondPlace = topThree.length > 1 ? topThree[1] : null;
    final thirdPlace = topThree.length > 2 ? topThree[2] : null;

    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.grey.shade400.withValues(alpha: 0.6), Colors.grey.shade600.withValues(alpha: 0.4)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.amber.shade400.withValues(alpha: 0.8), Colors.amber.shade700.withValues(alpha: 0.6)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border.all(color: Colors.amber.shade200, width: 1),
                      boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)],
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.orange.shade400.withValues(alpha: 0.6), Colors.orange.shade700.withValues(alpha: 0.4)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: secondPlace != null ? _buildPodiumUser(secondPlace, 2) : const SizedBox(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 55),
                    child: firstPlace != null ? _buildPodiumUser(firstPlace, 1) : const SizedBox(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: thirdPlace != null ? _buildPodiumUser(thirdPlace, 3) : const SizedBox()
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(LeaderboardUser user, int position) {
    final isFirst = position == 1;
    final avatarSize = isFirst ? 90.0 : 70.0;
    final frameSize = avatarSize * 1.3;

    Color borderColor;
    if (position == 1) {
      borderColor = Colors.amber.shade400;
    } else if (position == 2) {
      borderColor = Colors.grey.shade400;
    } else {
      borderColor = Colors.orange.shade400;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [borderColor, borderColor.withValues(alpha: 0.6)]),
                  boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: user.pictureUrl != null && user.pictureUrl!.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: user.pictureUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade800,
                        child: Icon(Icons.person, color: Colors.white, size: avatarSize * 0.5),
                      );
                    },
                  )
                      : Container(
                    color: Colors.grey.shade800,
                    child: Icon(Icons.person, color: Colors.white, size: avatarSize * 0.5),
                  ),
                ),
              ),
              // Overlay the Frame based on 1.3x size logic
              Positioned(
                width: frameSize,
                height: frameSize,
                child: IgnorePointer(
                  child: ActiveFrameWidget(userId: user.id, size: frameSize),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.name,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text('ID: ${user.displayId}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 12),
              const SizedBox(width: 3),
              Text(
                _formatNumber(user.totalValue),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankList(List<LeaderboardUser> users) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: users.length,
            separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            itemBuilder: (context, index) {
              return _buildRankListItem(index + 4, users[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRankListItem(int rank, LeaderboardUser user) {
    final double avatarSize = 45.0;
    final double frameSize = avatarSize * 1.3; // 45 * 1.3 = 58.5

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]),
                    boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: user.pictureUrl != null && user.pictureUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: user.pictureUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.person, color: Colors.white, size: 25),
                        );
                      },
                    )
                        : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.person, color: Colors.white, size: 25),
                    ),
                  ),
                ),
                // Overlay the Frame based on 1.3x size logic
                Positioned(
                  width: frameSize,
                  height: frameSize,
                  child: IgnorePointer(
                    child: ActiveFrameWidget(userId: user.id, size: frameSize),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('ID: ${user.displayId}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade400.withValues(alpha: 0.6), Colors.pink.shade600.withValues(alpha: 0.4)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                const SizedBox(width: 3),
                Text(
                  _formatNumber(user.totalValue),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
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