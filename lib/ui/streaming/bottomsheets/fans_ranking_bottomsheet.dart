import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/widgets/active_frame_widget.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../profile/profile_page.dart'; // For getSentLevel

class FansRankingBottomSheet extends StatefulWidget {
  final String hostId;

  const FansRankingBottomSheet({super.key, required this.hostId});

  @override
  State<FansRankingBottomSheet> createState() => _FansRankingBottomSheetState();
}

class _FansRankingBottomSheetState extends State<FansRankingBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _periodController;
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  int _totalCoins = 0;

  @override
  void initState() {
    super.initState();
    _periodController = TabController(length: 3, vsync: this, initialIndex: 0);
    _periodController.addListener(_handleTabSelection);
    _loadRanking();
    _loadTotalCoins();
  }

  void _handleTabSelection() {
    if (!_periodController.indexIsChanging) {
      _loadRanking();
    }
  }

  Future<void> _loadTotalCoins() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.hostId).get();
      if (doc.exists) {
        setState(() {
          final data = doc.data();
          if (data != null) {
            _totalCoins = (data['balance'] as num?)?.toInt() ?? 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading total coins: $e');
    }
  }

  Future<void> _loadRanking() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String period = _periodController.index == 0
          ? 'daily'
          : _periodController.index == 1
          ? 'weekly'
          : 'monthly';

      final data = await ProfileService.getTopFansForHost(
        hostId: widget.hostId,
        period: period,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _leaderboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fans ranking: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(2)}K';
    } else {
      return number.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF2d1b2b), // Premium Dark Purple Background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Fans Ranking',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildPeriodTabs(),
          const SizedBox(height: 16),
          _buildTotalDiamondsHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                : _leaderboardData.isEmpty
                    ? _buildEmptyState()
                    : _buildRankList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDiamondsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond_outlined, color: Colors.cyan, size: 16),
          const SizedBox(width: 6),
          Text(
            'Total Received: ${_formatNumber(_totalCoins)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _periodController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE5B95B), Color(0xFFC4A462)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC4A462).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'Daily'),
          Tab(text: 'Weekly'),
          Tab(text: 'Monthly'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars_rounded, color: Colors.white.withValues(alpha: 0.1), size: 64),
          const SizedBox(height: 12),
          Text(
            'No rankings yet for this period',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildRankList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: _leaderboardData.length,
      itemBuilder: (context, index) {
        return _buildRankListItem(index + 1, _leaderboardData[index]);
      },
    );
  }

  Widget _buildRankListItem(int rank, LeaderboardUser user) {
    final double avatarSize = 44.0;
    final double frameSize = avatarSize * 1.35;
    final int level = getSentLevel(user.totalSent);

    Color rankColor = Colors.white54;
    double rankSize = 16.0;
    if (rank == 1) { rankColor = const Color(0xFFFFD700); } // Gold
    else if (rank == 2) { rankColor = const Color(0xFFC0C0C0); } // Silver
    else if (rank == 3) { rankColor = const Color(0xFFCD7F32); } // Bronze

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rankColor,
                fontSize: rank <= 3 ? 20 : rankSize,
                fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                fontStyle: rank <= 3 ? FontStyle.italic : FontStyle.normal,
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank <= 3 ? rankColor.withValues(alpha: 0.5) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: Colors.grey.shade900,
                    backgroundImage: user.pictureUrl != null && user.pictureUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.pictureUrl!)
                        : null,
                    child: user.pictureUrl == null || user.pictureUrl!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54, size: 24)
                        : null,
                  ),
                ),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Image.asset(
                  'assets/images/levels/rank_caifu_cf_$level.png',
                  height: 18,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Lv $level',
                      style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_outlined, color: Colors.cyan, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(user.totalValue),
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Coins',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showFansRankingBottomSheet(BuildContext context, String hostId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => FansRankingBottomSheet(hostId: hostId),
  );
}
