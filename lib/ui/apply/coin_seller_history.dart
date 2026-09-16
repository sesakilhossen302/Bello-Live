import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

class CoinSellerHistoryPage extends StatefulWidget {
  const CoinSellerHistoryPage({super.key});

  @override
  State<CoinSellerHistoryPage> createState() => _CoinSellerHistoryPageState();
}

class _CoinSellerHistoryPageState extends State<CoinSellerHistoryPage> {
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const GlobalAppBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: currentUserId == null
                      ? const Center(child: Text('User not logged in', style: TextStyle(color: Colors.white)))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('coin_history')
                              .where('senderUid', isEqualTo: currentUserId)
                              .where('action', isEqualTo: 'reseller_transfer')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.pink));
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                                ),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text('No transfer history found', style: TextStyle(color: Colors.white70)),
                              );
                            }

                            final docs = snapshot.data!.docs.toList();
                            // Sort locally by timestamp descending
                            docs.sort((a, b) {
                              final timeA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                              final timeB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                              if (timeA == null) return 1;
                              if (timeB == null) return -1;
                              return timeB.compareTo(timeA);
                            });

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final amount = data['amount'] ?? 0;
                                final timestamp = data['timestamp'] as Timestamp?;
                                String dateStr = 'Unknown date';
                                if (timestamp != null) {
                                  dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate());
                                }

                                final targetDisplayId = data['targetDisplayId'];
                                final targetUserId = data['userId'] as String?;

                                return FutureBuilder<DocumentSnapshot>(
                                  future: targetUserId != null 
                                      ? FirebaseFirestore.instance.collection('users').doc(targetUserId).get() 
                                      : Future.value(null),
                                  builder: (context, userSnapshot) {
                                    String displayName = targetDisplayId != null ? 'User ID: $targetDisplayId' : 'Sent to User';
                                    String? photoUrl;
                                    
                                    if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                      final name = userData['displayName'] ?? userData['name'];
                                      photoUrl = userData['photoUrl'] ?? userData['profilePic'];
                                      if (name != null && name.toString().isNotEmpty) {
                                        displayName = name;
                                        if (targetDisplayId != null) {
                                          displayName = '$name (ID: $targetDisplayId)';
                                        }
                                      }
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 15),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors.cyanAccent.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 1),
                                              image: photoUrl != null && photoUrl.isNotEmpty
                                                  ? DecorationImage(
                                                      image: NetworkImage(photoUrl),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: photoUrl == null || photoUrl.isEmpty
                                                ? const Icon(Icons.person, color: Colors.cyanAccent, size: 24)
                                                : null,
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  displayName,
                                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  dateStr,
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '-${_formatNumber(amount)}',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'Transfer History',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.pink.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
          const SizedBox(width: 40), // Placeholder for symmetry
        ],
      ),
    );
  }
}
