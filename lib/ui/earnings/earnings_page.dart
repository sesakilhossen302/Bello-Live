import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../theme/app_theme.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  DateTime selectedMonth = DateTime.now();
  bool isLoading = true;
  bool isHost = false;

  // Dynamic variables fetched from Firestore
  int currentMonthRate = 0;
  int giftReceiveTarget = 2000000;
  int giftReceiveReward = 0;

  Map<String, dynamic>? earningsData;

  @override
  void initState() {
    super.initState();
    _checkHostStatus();
  }

  Future<void> _checkHostStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final userDoc = await ProfileService.getUserProfile(userId);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          isHost = data['isHost'] ?? false;
        });

        if (isHost) {
          _loadEarningsData();
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error checking host status: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchDynamicSettings() async {
    try {
      final monthKey = DateFormat('yyyy-MM').format(selectedMonth);

      final dayDoc = await FirebaseFirestore.instance
          .collection('SalarySettings')
          .doc('DaySettings')
          .get(const GetOptions(source: Source.server));

      if (dayDoc.exists && dayDoc.data() != null && dayDoc.data()!.containsKey(monthKey)) {
        currentMonthRate = (dayDoc.data()![monthKey] as num).toInt();
      } else {
        currentMonthRate = 0;
      }

      final receiveDoc = await FirebaseFirestore.instance
          .collection('SalarySettings')
          .doc('GiftReceive')
          .get(const GetOptions(source: Source.server));

      if (receiveDoc.exists && receiveDoc.data() != null) {
        final data = receiveDoc.data()!;
        giftReceiveTarget = (data['giftTarget'] as num?)?.toInt() ?? 2000000;
        giftReceiveReward = (data['giftReward'] as num?)?.toInt() ?? 0;
      } else {
        giftReceiveTarget = 2000000;
        giftReceiveReward = 0;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching dynamic settings: $e');
      if (mounted) {
        setState(() {
          currentMonthRate = 0;
          giftReceiveTarget = 2000000;
          giftReceiveReward = 0;
        });
      }
    }
  }

  Future<void> _loadEarningsData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _fetchDynamicSettings(),
        ProfileService.getMonthlyEarnings(userId: userId, year: selectedMonth.year, month: selectedMonth.month),
      ]);

      final data = results[1] as Map<String, dynamic>;

      setState(() {
        earningsData = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading earnings: $e');
      setState(() => isLoading = false);
    }
  }

  void _selectMonth() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: const Color(0xFF2d1b2b),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Select Month',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = DateTime(selectedMonth.year, index + 1);
                    final monthName = DateFormat('MMMM yyyy').format(month);
                    final isCurrent = month.month == selectedMonth.month && month.year == selectedMonth.year;

                    return ListTile(
                      title: Text(
                        monthName,
                        style: TextStyle(
                          color: isCurrent ? AppColors.pink : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isCurrent ? const Icon(Icons.check_circle, color: AppColors.pink) : null,
                      onTap: () => Navigator.pop(context, month),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != selectedMonth) {
      setState(() => selectedMonth = picked);
      _loadEarningsData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.pink))
                    : isHost
                        ? _buildHostEarningsView()
                        : _buildNonHostView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 20, top: 8, bottom: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isHost ? 'Earnings Dashboard' : 'Official Talent Instruction',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostEarningsView() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final validDays = earningsData?['validDays'] ?? 0;
    final audioMinutes = earningsData?['audioMinutes'] ?? 0;
    final videoMinutes = earningsData?['videoMinutes'] ?? 0;

    final rawReceivedGifts = earningsData?['revenue'] ?? 0;

    int receiveBonus = 0;
    if (giftReceiveTarget > 0 && giftReceiveReward > 0) {
      receiveBonus = (rawReceivedGifts ~/ giftReceiveTarget) * giftReceiveReward;
    }

    final finalReceivedAmount = rawReceivedGifts + receiveBonus;
    final calculatedDailyBonus = validDays * currentMonthRate;
    final total = finalReceivedAmount + calculatedDailyBonus;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Header
          StreamBuilder<DocumentSnapshot>(
            stream: ProfileService.getUserProfileStream(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 80);
              final data = snapshot.data!.data() as Map<String, dynamic>;

              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                      backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                      child: data['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['displayName'] ?? 'User',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${data['displayId'] ?? 'N/A'}',
                            style: const TextStyle(color: AppColors.pink400, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Text(
                        'HOST',
                        style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Month Selector
          Center(
            child: GestureDetector(
              onTap: _selectMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.pink, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: AppColors.pink),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Stats Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildStatBox(title: "Valid Days", value: "$validDays", icon: Icons.verified, color: Colors.greenAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(title: "Audio Live", value: _formatDuration(audioMinutes), icon: Icons.mic, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(title: "Video Live", value: _formatDuration(videoMinutes), icon: Icons.videocam, color: Colors.purpleAccent),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Earnings Breakdown
          const Text(
            "Earnings Breakdown",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildEarningRow('Received Gifts Revenue', finalReceivedAmount, isPositive: true),
          const SizedBox(height: 12),
          _buildEarningRow('Daily Active Reward', calculatedDailyBonus, isPositive: true),
          const SizedBox(height: 16),
          _buildEarningRow('Total Target Revenue', total, isTotal: true),

          const SizedBox(height: 24),

          // Note
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Totals below 200,000 diamonds cannot be withdrawn and will remain in your account until the next payment month.',
                    style: TextStyle(color: Colors.orange.shade100, fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatBox({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningRow(String label, int amount, {bool isPositive = false, bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isTotal ? AppColors.pink.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isTotal ? AppColors.pink : Colors.white.withValues(alpha: 0.15), width: isTotal ? 2 : 1),
        boxShadow: isTotal
            ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white70,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          Row(
            children: [
              if (isTotal)
                const Icon(Icons.stars, color: Colors.amber, size: 24)
              else
                const Icon(Icons.diamond, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                '${isPositive ? '+' : ''}${_formatNumber(amount)}',
                style: TextStyle(
                  color: isTotal ? Colors.amberAccent : Colors.white,
                  fontSize: isTotal ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(1, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  // --- PREMIUM NON-HOST / INSTRUCTION VIEW ---
  Widget _buildNonHostView() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: ProfileService.getUserProfileStream(currentUserId),
      builder: (context, snapshot) {
        int liveEarning = 0;
        int gameEarning = 0;
        int giftingEarning = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          liveEarning = data['liveEarnings'] ?? data['revenue'] ?? data['todaysRevenue'] ?? 0;
          gameEarning = data['gameEarnings'] ?? 0;
          giftingEarning = data['totalReceived'] ?? data['diamonds'] ?? 0;
        }

        int totalEarning = liveEarning + gameEarning + giftingEarning;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Title Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.barColor.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.pink, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Official Talent Guide",
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Everything you need to know about streaming & earning rewards.",
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Requirements Section
              _buildSectionTitle("Requirements to Become Official Talent", Icons.check_circle_outline, Colors.greenAccent),
              const SizedBox(height: 14),
              _buildInstructionCard(
                title: "Gems Earning Target",
                description: "Earn at least 2,000,000 gems from your broadcasts to qualify and apply as an Official Streamer.",
                icon: Icons.diamond,
                iconColor: Colors.cyanAccent,
              ),
              const SizedBox(height: 12),
              _buildInstructionCard(
                title: "Direct Agency Onboarding",
                description: "If you already have an Agency ID, you can join an Agency instantly and bypass the gems threshold.",
                icon: Icons.business_center,
                iconColor: Colors.amberAccent,
              ),

              const SizedBox(height: 28),

              // Benefits Section
              _buildSectionTitle("Why Become an Official Streamer?", Icons.star_border, Colors.amber),
              const SizedBox(height: 14),
              _buildBenefitTile("Real Money Payouts", "Receive regular monthly salary allowances plus real money conversions from your gems balance."),
              const SizedBox(height: 10),
              _buildBenefitTile("Homepage Spotlight", "Your live broadcasts will automatically appear under the 'Popular' category for maximum user engagement."),
              const SizedBox(height: 10),
              _buildBenefitTile("Discovery & New Star Ribbon", "Unlock a prestigious 'New Star' ribbon on your profile and get special ranking placement."),
              const SizedBox(height: 10),
              _buildBenefitTile("Exclusive Training", "Get official 24/7 priority support, streamer training, and agency perks directly from our core team."),

              const SizedBox(height: 32),

              // --- COIN EARNING SUMMARY BOXES ---
              const Text(
                "Your Current Earnings",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildEarningSummaryBox(
                      title: "Live Earning",
                      amount: liveEarning,
                      icon: Icons.mic_external_on,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEarningSummaryBox(
                      title: "Game Earning",
                      amount: gameEarning,
                      icon: Icons.sports_esports,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildEarningSummaryBox(
                      title: "Gifting Earning",
                      amount: giftingEarning,
                      icon: Icons.card_giftcard,
                      color: Colors.pinkAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEarningSummaryBox(
                      title: "Total Earning",
                      amount: totalEarning,
                      icon: Icons.emoji_events,
                      color: Colors.amberAccent,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- DAILY STREAM BONUS TARGET BANNER ---
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 25, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time_filled, color: Colors.white, size: 40),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department, color: Colors.yellowAccent, size: 20),
                              SizedBox(width: 6),
                              Text(
                                "Daily Streaming Target",
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Stream for a minimum of 1 hour daily (Audio or Video live) to receive 4,000 Coins reward!",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Notice Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Age Restriction Notice",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "MP Live requires all broadcasters to be at least 18 years old. Underage applications will be strictly declined.",
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard({required String title, required String description, required IconData icon, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile(String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.pink, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningSummaryBox({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isFullWidth ? 20 : 16,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        gradient: isFullWidth
            ? LinearGradient(
                colors: [
                  AppColors.pink.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: !isFullWidth ? Colors.black.withValues(alpha: 0.35) : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFullWidth ? AppColors.pink : color.withValues(alpha: 0.5),
          width: isFullWidth ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isFullWidth ? AppColors.pink : color).withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isFullWidth ? 12 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isFullWidth ? 32 : 24),
          ),
          SizedBox(width: isFullWidth ? 16 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.diamond, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        _formatNumber(amount),
                        style: TextStyle(
                          color: isFullWidth ? Colors.amberAccent : Colors.white,
                          fontSize: isFullWidth ? 28 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

