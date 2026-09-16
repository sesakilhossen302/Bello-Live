import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:picture_live/theme/app_theme.dart';

class HostListPage extends StatelessWidget {
  final String agencyCode;

  const HostListPage({super.key, required this.agencyCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const GlobalAppBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
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
                        'Host List',
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
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('agencyCode', isEqualTo: agencyCode)
                        .where('isHost', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.pink));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading hosts', style: TextStyle(color: Colors.white70)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No hosts found for this agency.', style: TextStyle(color: Colors.white70, fontSize: 16)));
                      }

                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['displayName'] ?? data['name'] ?? 'Unknown';
                          final displayId = data['displayId'] ?? 'N/A';
                          final hostType = data['hostType'] ?? 'Unknown';
                          final photoUrl = data['photoUrl'] as String?;
                          final earningDiamond = data['earningDiamond'] ?? data['diamonds'] ?? data['earningDiamonds'] ?? 0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: $displayId | Type: $hostType',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Earning', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(CupertinoIcons.suit_diamond_fill, color: Colors.cyanAccent, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$earningDiamond',
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
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
