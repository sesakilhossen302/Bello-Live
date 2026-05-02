import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyInvitesPage extends StatefulWidget {
  const MyInvitesPage({super.key});

  @override
  State<MyInvitesPage> createState() => _MyInvitesPageState();
}

class _MyInvitesPageState extends State<MyInvitesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final String referralCode = "LUNA123"; // Dummy referral code
  final List<Map<String, dynamic>> invitedFriends = [
    {"name": "Alice Kim", "status": "Joined"},
    {"name": "John Park", "status": "Pending"},
    {"name": "Sakura Lee", "status": "Joined"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000000), Color(0xFF1a0a0a), Color(0xFF2d1b2b), Color(0xFF4a2c4a), Color(0xFFff6b9d)],
            stops: [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Text(
                      "My Invites",
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
                  ],
                ),
              ),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.purple.shade400]),
                  ),
                  indicatorColor: Colors.transparent,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: "Invite a Friend"),
                    Tab(text: "My Invites"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildInviteFriendTab(), _buildMyInvitesTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteFriendTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard, size: 80, color: Colors.pinkAccent),
            const SizedBox(height: 20),
            Text(
              "Invite friends and earn rewards!",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Referral Code Card
            Container(
              padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      const Text("Your Referral Code", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        referralCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          debugPrint("Share referral code tapped");
                        },
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text("Share", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyInvitesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: invitedFriends.length,
      itemBuilder: (context, index) {
        final friend = invitedFriends[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.pinkAccent.withValues(alpha: 0.3),
                child: Text(friend["name"][0], style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  friend["name"],
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: friend["status"] == "Joined" ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                ),
                child: Text(
                  friend["status"],
                  style: TextStyle(
                    color: friend["status"] == "Joined" ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
