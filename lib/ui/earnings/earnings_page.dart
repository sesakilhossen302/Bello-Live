import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // Force fetch from server to avoid stale cache data
      final dayDoc = await FirebaseFirestore.instance
          .collection('SalarySettings')
          .doc('DaySettings')
          .get(const GetOptions(source: Source.server));

      if (dayDoc.exists && dayDoc.data() != null && dayDoc.data()!.containsKey(monthKey)) {
        currentMonthRate = (dayDoc.data()![monthKey] as num).toInt();
      } else {
        currentMonthRate = 0;
      }

      // Force fetch from server here as well
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
      // Note: If you use Source.server and the user is entirely offline,
      // it will throw an exception and land here.
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
      //  Run settings fetch AND earnings data fetch concurrently
      final results = await Future.wait([
        _fetchDynamicSettings(),
        ProfileService.getMonthlyEarnings(userId: userId, year: selectedMonth.year, month: selectedMonth.month),
      ]);

      // results[1] contains the map returned from getMonthlyEarnings
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Select Month',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                        ),
                      ),
                      trailing: isCurrent ? Icon(Icons.check, color: AppColors.pink) : null,
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
                    ? Center(child: CircularProgressIndicator(color: AppColors.pink))
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
      padding: const EdgeInsets.only(left: 0, right: 20, top: 10, bottom: 20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              isHost ? 'Earnings' : 'Official Talent Instruction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: AppColors.pink, blurRadius: 10, offset: const Offset(0, 2))],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHostEarningsView() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final validDays = earningsData?['validDays'] ?? 0;
    final audioMinutes = earningsData?['audioMinutes'] ?? 0;
    final videoMinutes = earningsData?['videoMinutes'] ?? 0;

    // Core gifts received from users
    final rawReceivedGifts = earningsData?['revenue'] ?? 0;

    // --- NEW LOGIC: Calculate Target Receive Bonus ---
    int receiveBonus = 0;
    if (giftReceiveTarget > 0 && giftReceiveReward > 0) {
      // e.g., (4,500,000 ~/ 2,000,000) = 2. Then 2 * 100,000 = 200,000 bonus
      receiveBonus = (rawReceivedGifts ~/ giftReceiveTarget) * giftReceiveReward;
    }

    // Add bonus to the baseline received amount
    final finalReceivedAmount = rawReceivedGifts + receiveBonus;

    // Daily active salary based on month specific rate
    final calculatedDailyBonus = validDays * currentMonthRate;

    // Grand total
    final total = finalReceivedAmount + calculatedDailyBonus;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- User Profile Header ---
          StreamBuilder<DocumentSnapshot>(
            stream: ProfileService.getUserProfileStream(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 80);
              final data = snapshot.data!.data() as Map<String, dynamic>;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                      backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                      child: data['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['displayName'] ?? 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${data['displayId'] ?? 'N/A'}',
                          style: TextStyle(color: AppColors.pink400, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'HOST',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down, color: AppColors.pink),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Table Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.pink.withValues(alpha: 0.3), AppColors.pink.withValues(alpha: 0.1)]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Valid Days',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Audio Live',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Video Live',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Table Data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$validDays',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.pink, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDuration(audioMinutes),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDuration(videoMinutes),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Earnings Breakdown
          _buildEarningRow('Received', finalReceivedAmount, isPositive: true),
          const SizedBox(height: 12),
          _buildEarningRow('Reward', calculatedDailyBonus, isPositive: true),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 12),
          _buildEarningRow('Total Target', total, isTotal: true),

          const SizedBox(height: 20),

          // Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Totals below 200,000 diamonds cannot be withdrawn and will remain in your account until the next payment month.',
                    style: TextStyle(color: Colors.orange.shade100, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEarningRow(String label, int amount, {bool isPositive = false, bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTotal ? AppColors.pink.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTotal ? AppColors.pink.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white70,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${_formatNumber(amount)}',
            style: TextStyle(
              color: isTotal ? AppColors.pink : Colors.white,
              fontSize: isTotal ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildNonHostView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'What you need to become an official Talent',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pink400,
                    shadows: [Shadow(color: AppColors.pink.withValues(alpha: 0.3), blurRadius: 5)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBulletPoint('Official Talent Requirements'),
          const SizedBox(height: 10),
          _buildBulletPoint('If you have earned at least 2,000,000 gems, then you can apply to be an official talent.'),
          const SizedBox(height: 10),
          _buildOrText(),
          const SizedBox(height: 10),
          _buildBulletPoint(
            'If you have an Agency ID and agency you would like to join, you can apply with the Agency ID and Join into an Agency right away.',
          ),
          const SizedBox(height: 40),
          _buildSectionTitle('Why should you become an official talent?'),
          const SizedBox(height: 20),
          _buildBulletPoint(
            'You can earn real money from streaming. You will receive both an allowance and money from the gems you earn!',
          ),
          const SizedBox(height: 10),
          _buildBulletPoint(
            'When you broadcast, your stream will appear on the Popular category on the homepage. This way the most users will see you.',
          ),
          const SizedBox(height: 10),
          _buildBulletPoint(
            'Special placement in the Discovery section of the app and a New Star ribbon on your broadcast. We want everyone to know how special you are!',
          ),
          const SizedBox(height: 10),
          _buildBulletPoint(
            'Receive training, support and other perks from the team at Picture Live and our crew of trusted agencies!',
          ),
          const SizedBox(height: 40),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Notice:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pink400,
                    shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 5)],
                  ),
                ),
                const TextSpan(
                  text:
                      '\nPICTURE Live does not allow streamer under 18 to stream. If you are under age, your application will not be accepted. Please apply after you turn 18 years old.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          StreamBuilder<int>(
            stream: ProfileService.getUserDiamondsStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              return _buildGemsInfo(snapshot.data ?? 0);
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: () {
                debugPrint('Continue button tapped!');
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.pink,
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'I have an Agency ID',
              style: TextStyle(
                color: Colors.white70,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.pink400,
        shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 5)],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('●  ', style: TextStyle(color: Colors.white, fontSize: 14)),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildOrText() {
    return const Center(
      child: Text('Or', style: TextStyle(color: Colors.white, fontSize: 14)),
    );
  }

  Widget _buildGemsInfo(int currentDiamonds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Gems Balance: $currentDiamonds gems', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 5),
        const Text('Gems Required to Apply: 2,000,000 gems', style: TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}
