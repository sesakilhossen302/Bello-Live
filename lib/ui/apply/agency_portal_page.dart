import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:picture_live/data/remote/firebase/profile_services.dart';
import 'package:picture_live/theme/app_theme.dart';
import 'host_approval_page.dart';
import 'host_list_page.dart';
import 'host_coins_page.dart';

class AgencyPortalPage extends StatefulWidget {
  const AgencyPortalPage({super.key});

  @override
  State<AgencyPortalPage> createState() => _AgencyPortalPageState();
}

class _AgencyPortalPageState extends State<AgencyPortalPage> {
  bool _isLoading = true;
  bool _isAgency = false;
  Map<String, dynamic>? _agencyData;

  @override
  void initState() {
    super.initState();
    _loadAgencyData();
  }

  Future<void> _loadAgencyData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final userDoc = await ProfileService.getUserProfile(userId);
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _isAgency = userData['isAgency'] == true || userData['isagency'] == true;
      }

      if (_isAgency) {
        final agencyQuery = await FirebaseFirestore.instance
            .collection('agencies')
            .where('ownerId', isEqualTo: userId)
            .limit(1)
            .get();

        if (agencyQuery.docs.isNotEmpty) {
          final doc = agencyQuery.docs.first;
          _agencyData = doc.data();
          _agencyData!['agencyId'] = doc.id;
        } else {
          final doc = await ProfileService.getAgencyApplicationStatus();
          if (doc.exists) {
            _agencyData = doc.data() as Map<String, dynamic>;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading agency data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GlobalAppBackground(),
            Center(child: CircularProgressIndicator(color: AppColors.pink)),
          ],
        ),
      );
    }

    if (!_isAgency) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const GlobalAppBackground(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Agency Portal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "You need to apply for an agency first to access this portal.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final agencyName = _agencyData?['name'] ?? _agencyData?['agencyName'] ?? 'Unknown Agency';
    final agencyCode = _agencyData?['agencyId'] ?? _agencyData?['agencyCode'] ?? _agencyData?['agencycode'] ?? 'N/A';
    final whatsapp = _agencyData?['whatsapp'] ?? _agencyData?['whatsappNumber'] ?? 'N/A';
    final holderName = _agencyData?['holderName'] ?? 'N/A';
    final logo = _agencyData?['logo'];
    final country = _agencyData?['country'] ?? _agencyData?['location'];
    final status = _agencyData?['status'] ?? 'Pending';
    final createdAt = _agencyData?['createdAt'] ?? _agencyData?['submittedAt'];
    String dateStr = 'Unknown';
    if (createdAt != null && createdAt is Timestamp) {
      final date = createdAt.toDate();
      dateStr = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const GlobalAppBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Back button & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.pink.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pink.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: const Text(
                        'Agency Portal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        _buildAgencyHeader(agencyName, agencyCode, whatsapp, logo, holderName, country),
                        const SizedBox(height: 16),
                        
                        // Horizontal Stats Cards
                        _buildStatsHorizontalList(agencyCode),
                        const SizedBox(height: 16),
                        
                        // Grid of Buttons
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 3.2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          children: [
                            _buildGlassGridButton(
                              'Host Approval',
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostApprovalPage(
                                      agencyCode: agencyCode,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildGlassGridButton(
                              'Host List',
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostListPage(
                                      agencyCode: agencyCode,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildGlassGridButton(
                              'Current Host Coins',
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostCoinsPage(
                                      agencyCode: agencyCode,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildGlassGridButton(
                              'Total Coins',
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostCoinsPage(
                                      agencyCode: agencyCode,
                                      isEarning: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildGlassGridButton(
                              'Top Earner Host',
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostCoinsPage(
                                      agencyCode: agencyCode,
                                      isEarning: true,
                                      isTopEarner: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Back Button Overlay
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencyHeader(String name, String code, String whatsapp, String? logo, String holderName, String? country) {
    return Column(
      children: [

        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Holder: $holderName',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Agency ID: $code',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Agency ID copied!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Icon(
                Icons.copy,
                color: AppColors.pink,
                size: 16,
              ),
            ),
            if (country != null && country.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.location_solid, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                country,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGlassGridButton(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHorizontalList(String agencyCode) {
    return SizedBox(
      height: 140,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCardStream(
              title: 'Total Hosts',
              icon: Icons.group,
              iconColor: Colors.pinkAccent,
              stream: FirebaseFirestore.instance.collection('users').where('agencyCode', isEqualTo: agencyCode).where('isHost', isEqualTo: true).snapshots(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCardStream(
              title: 'Pending Approval',
              icon: Icons.access_time_filled,
              iconColor: Colors.orangeAccent,
              stream: FirebaseFirestore.instance.collection('hosting_applications').where('agencyCode', isEqualTo: agencyCode).where('status', isEqualTo: 'pending').snapshots(),
              bottomWidget: const Row(
                children: [
                  Text('View all', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.orangeAccent, size: 12),
                ],
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => HostApprovalPage(agencyCode: agencyCode)));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardStream({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Stream<QuerySnapshot> stream,
    Widget? bottomWidget,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1021),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Text('Error', style: TextStyle(color: Colors.red, fontSize: 14));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      );
                    }
                    
                    final count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      count.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                if (bottomWidget != null) ...[
                  const SizedBox(height: 6),
                  bottomWidget,
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, color: iconColor, size: 10),
                      const SizedBox(width: 2),
                      Text('8.2%', style: TextStyle(color: iconColor, fontSize: 10)),
                      const SizedBox(width: 4),
                      const Text('vs last week', style: TextStyle(color: Colors.white54, fontSize: 9)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
