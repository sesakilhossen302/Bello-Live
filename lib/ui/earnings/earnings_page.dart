import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  String earningNoteText = 'Totals below 200,000 diamonds cannot be withdrawn and will remain in your account until the next payment month.';

  Map<String, dynamic>? earningsData;

  @override
  void initState() {
    super.initState();
    _checkHostStatus();
  }

  Stream<int> _buildGiftingStream(String userId) {
    final now = DateTime.now();
    if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
      return ProfileService.getMonthlyReceivedDiamondsStream(userId);
    } else {
      return Stream.value(earningsData?['revenue'] ?? 0);
    }
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
          isHost = data['isHost'] ?? false; // Reverted back to correct role check
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

      final noteDoc = await FirebaseFirestore.instance
          .collection('earningnote')
          .doc('note')
          .get(const GetOptions(source: Source.server));

      if (noteDoc.exists && noteDoc.data() != null) {
        final noteStr = noteDoc.data()!['note1'];
        if (noteStr != null && noteStr.toString().isNotEmpty) {
          earningNoteText = noteStr.toString();
        }
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
      backgroundColor: const Color(0xFF091433),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : isHost
                      ? _buildHostEarningsView()
                      : _buildNonHostView(),
            ),
          ],
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
          const Expanded(
            child: Text(
              'Earnings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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

    final calculatedDailyBonus = earningsData?['dailyRewardTotal'] ?? 0;
    final total = rawReceivedGifts + calculatedDailyBonus;

    const containerColor = Color(0xFF0F1E42);
    final borderColor = Colors.white.withValues(alpha: 0.08);

    final dailyRecords = earningsData?['dailyRecords'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // User Profile Header
          StreamBuilder<DocumentSnapshot>(
            stream: ProfileService.getUserProfileStream(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 80);
              final data = snapshot.data!.data() as Map<String, dynamic>;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                      backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                      child: data['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['displayName'] ?? 'User',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${data['displayId'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'HOST',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Month Selector
          Center(
            child: GestureDetector(
              onTap: _selectMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Room Timer — shows if host currently has a room open
          _LiveRoomTimerCard(userId: userId),
          const SizedBox(height: 16),

          // Stats Table
          Container(
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF162B5B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(child: Center(child: Text("Valid Days", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)))),
                      Expanded(child: Center(child: Text("Audio Live", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)))),
                      Expanded(child: Center(child: Text("Video Live", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            "$validDays",
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _formatDuration(audioMinutes),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _formatDuration(videoMinutes),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Earnings List — Gifting is real-time
          StreamBuilder<int>(
            stream: _buildGiftingStream(userId),
            builder: (context, giftSnap) {
              final liveGiftTotal = giftSnap.data ?? rawReceivedGifts;
              final liveTotal = liveGiftTotal + calculatedDailyBonus;

              return Column(
                children: [
                  _buildEarningItem(
                    'Gifting (Coins)',
                    liveGiftTotal,
                    isLive: true,
                    isLoading: giftSnap.connectionState == ConnectionState.waiting,
                  ),
                  const SizedBox(height: 12),
                  _buildEarningItem('Daily Reward', calculatedDailyBonus),
                  const SizedBox(height: 16),

                  // Total Target
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Target',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatNumber(liveTotal),
                          style: const TextStyle(color: Color(0xFFFFB300), fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    earningNoteText,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Daily Details Section
          const Text(
            'Daily Details',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (dailyRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: const Center(
                child: Text(
                  'No streaming records for this month',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            )
          else
            Column(
              children: dailyRecords.map<Widget>((record) {
                final date = record['date'] as DateTime?;
                final dateStr = record['dateString'] as String? ?? '';
                final formattedDate = date != null ? DateFormat('dd MMMM yyyy').format(date) : dateStr;
                final audioMins = (record['audioMinutes'] as num?)?.toInt() ?? 0;
                final videoMins = (record['videoMinutes'] as num?)?.toInt() ?? 0;
                final dailyReward = (record['dailyReward'] as num?)?.toInt() ?? 0;
                final isValid = record['isValidDay'] as bool? ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isValid ? Colors.green.withValues(alpha: 0.3) : borderColor,
                      width: isValid ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          if (isValid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'Valid Day',
                                style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Audio Live', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDuration(audioMins),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Video Live', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _formatDuration(videoMins),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Daily Reward', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                dailyReward > 0 ? '+${_formatNumber(dailyReward)}' : '0',
                                style: TextStyle(
                                  color: dailyReward > 0 ? Colors.greenAccent : Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEarningItem(
    String label,
    int amount, {
    bool isLive = false,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isLive ? Colors.green.withValues(alpha: 0.1) : const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? Colors.green.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                )
              : Text(
                  '+${_formatNumber(amount)}',
                  style: TextStyle(
                    color: isLive ? Colors.greenAccent : const Color(0xFFFFB300),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes == 0) return '0 m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0 && mins > 0) {
      return '$hours h $mins m';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$mins m';
    }
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
        int giftingEarning = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          liveEarning = data['liveEarnings'] ?? data['revenue'] ?? data['todaysRevenue'] ?? 0;
          giftingEarning = data['diamonds'] ?? 0;
        }

        int totalEarning = liveEarning + giftingEarning;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),



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
                      title: "Gifting Earning",
                      amount: giftingEarning,
                      icon: Icons.card_giftcard,
                      color: Colors.pinkAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildEarningSummaryBox(
                      title: "Total Earning",
                      amount: totalEarning,
                      icon: Icons.account_balance_wallet,
                      color: Colors.amber,
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

// ─────────────────────────────────────────────────────────────────────────────
// Live Room Timer Card
// Shows how long the host's current audio or video board has been open.
// Queries Firebase Realtime Database for active rooms where hostId == userId.
// ─────────────────────────────────────────────────────────────────────────────
class _LiveRoomTimerCard extends StatefulWidget {
  final String userId;
  const _LiveRoomTimerCard({required this.userId});

  @override
  State<_LiveRoomTimerCard> createState() => _LiveRoomTimerCardState();
}

class _LiveRoomTimerCardState extends State<_LiveRoomTimerCard> {
  // Detected active room info
  int? _audioRoomStart; // createdAt in milliseconds
  int? _videoRoomStart;

  Timer? _ticker;
  Duration _audioElapsed = Duration.zero;
  Duration _videoElapsed = Duration.zero;

  StreamSubscription<DatabaseEvent>? _audioSub;
  StreamSubscription<DatabaseEvent>? _videoSub;

  final _db = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _listenToRooms();
    // Tick every second to update elapsed times
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recalculate());
    });
  }

  void _recalculate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _audioElapsed = _audioRoomStart != null
        ? Duration(milliseconds: now - _audioRoomStart!)
        : Duration.zero;
    _videoElapsed = _videoRoomStart != null
        ? Duration(milliseconds: now - _videoRoomStart!)
        : Duration.zero;
  }

  void _listenToRooms() {
    // Audio rooms
    _audioSub = _db
        .ref('audioRooms')
        .orderByChild('hostId')
        .equalTo(widget.userId)
        .onValue
        .listen((event) {
      int? found;
      if (event.snapshot.exists) {
        final rooms = event.snapshot.value as Map<dynamic, dynamic>;
        for (final entry in rooms.entries) {
          final room = entry.value as Map<dynamic, dynamic>;
          final isActive = room['isActive'] == true;
          final createdAt = room['createdAt'] as int?;
          if (isActive && createdAt != null) {
            found = createdAt;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _audioRoomStart = found;
          _recalculate();
        });
      }
    });

    // Video rooms
    _videoSub = _db
        .ref('videoRooms')
        .orderByChild('hostId')
        .equalTo(widget.userId)
        .onValue
        .listen((event) {
      int? found;
      if (event.snapshot.exists) {
        final rooms = event.snapshot.value as Map<dynamic, dynamic>;
        for (final entry in rooms.entries) {
          final room = entry.value as Map<dynamic, dynamic>;
          final isActive = room['isActive'] == true;
          final createdAt = room['createdAt'] as int?;
          if (isActive && createdAt != null) {
            found = createdAt;
            break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _videoRoomStart = found;
          _recalculate();
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioSub?.cancel();
    _videoSub?.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioRoomStart != null;
    final hasVideo = _videoRoomStart != null;

    // Nothing to show if no active rooms
    if (!hasAudio && !hasVideo) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Blinking red dot
              _BlinkingDot(),
              const SizedBox(width: 8),
              const Text(
                'Live Board Open',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasAudio)
            _buildTimerRow(
              icon: Icons.mic,
              label: 'Audio Live',
              elapsed: _audioElapsed,
              color: Colors.blueAccent,
            ),
          if (hasAudio && hasVideo) const SizedBox(height: 8),
          if (hasVideo)
            _buildTimerRow(
              icon: Icons.videocam,
              label: 'Video Live',
              elapsed: _videoElapsed,
              color: Colors.purpleAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildTimerRow({
    required IconData icon,
    required String label,
    required Duration elapsed,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            _formatElapsed(elapsed),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small blinking red dot to indicate live status.
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

