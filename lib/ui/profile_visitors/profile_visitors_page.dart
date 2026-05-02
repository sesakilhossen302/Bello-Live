import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
// ADDED: Import the profile info bottom sheet (Update this path if necessary for your folder structure)
import '../live_streaming/bottomsheets/profile_info_bottomsheet.dart';

class ProfileVisitorsPage extends StatefulWidget {
  const ProfileVisitorsPage({super.key});

  @override
  State<ProfileVisitorsPage> createState() => _ProfileVisitorsPageState();
}

class _ProfileVisitorsPageState extends State<ProfileVisitorsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Get timestamp for 30 days ago
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    try {
      // Fetch the visitor documents from the current user's visitors subcollection
      final visitorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('visitors')
          .where('visitedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('visitedAt', descending: true)
          .get();

      List<Map<String, dynamic>> loadedVisitors = [];

      // For each visit, fetch the visitor's latest profile data
      for (var doc in visitorsSnapshot.docs) {
        final data = doc.data();
        final visitorId = data['visitorId'];
        final timestamp = data['visitedAt'] as Timestamp?;

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(visitorId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          loadedVisitors.add({
            'id': visitorId,
            'name': userData['displayName'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'],
            'visitedAt': timestamp?.toDate() ?? DateTime.now(),
          });
        }
      }

      setState(() {
        _visitors = loadedVisitors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile visitors: $e');
      setState(() => _isLoading = false);
    }
  }

  // Helper method to format how long ago they visited
  String _timeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays >= 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minutes ago';
    return 'Just now';
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
                      "Profile Visitors",
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

              const SizedBox(height: 10),

              // Visitors List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                    : _visitors.isEmpty
                    ? const Center(
                        child: Text("No recent visitors", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _visitors.length,
                        itemBuilder: (context, index) {
                          final visitor = _visitors[index];
                          final String id = visitor["id"];
                          final String name = visitor["name"];
                          final String? photoUrl = visitor["photoUrl"];
                          final DateTime visitedAt = visitor["visitedAt"];

                          // ADDED: GestureDetector to capture taps and open the bottom sheet
                          return GestureDetector(
                            onTap: () {
                              showProfileInfoBottomSheet(context, userId: id);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black.withValues(alpha: 0.3),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.pinkAccent.withValues(alpha: 0.3),
                                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                              ? CachedNetworkImageProvider(photoUrl)
                                              : null,
                                          child: photoUrl == null || photoUrl.isEmpty
                                              ? Text(
                                                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                                                  style: const TextStyle(color: Colors.white),
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          width: 52, // 40 * 1.3
                                          height: 52,
                                          child: IgnorePointer(child: ActiveFrameWidget(userId: id, size: 52)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Visited ${_timeAgo(visitedAt)}",
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                ],
                              ),
                            ),
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
}
