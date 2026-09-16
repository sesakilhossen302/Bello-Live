import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:picture_live/theme/app_theme.dart';

class HostCoinsPage extends StatelessWidget {
  final String agencyCode;
  final bool isEarning;
  final bool isTopEarner;

  const HostCoinsPage({super.key, required this.agencyCode, this.isEarning = true, this.isTopEarner = false});

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
                    Expanded(
                      child: Text(
                        isTopEarner ? 'Top Earner Hosts' : (isEarning ? 'Host Earnings Summary' : 'Host Wallet Summary'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                        return const Center(child: Text('Error loading data', style: TextStyle(color: Colors.white70)));
                      }
                      
                      final docs = snapshot.data?.docs.toList() ?? [];
                      
                      if (isTopEarner) {
                        docs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          
                          final diamondA = isEarning 
                              ? (dataA['earningDiamond'] ?? dataA['earningDiamonds'] ?? dataA['diamonds'] ?? 0)
                              : (dataA['diamonds'] ?? dataA['diamond'] ?? 0);
                              
                          final diamondB = isEarning 
                              ? (dataB['earningDiamond'] ?? dataB['earningDiamonds'] ?? dataB['diamonds'] ?? 0)
                              : (dataB['diamonds'] ?? dataB['diamond'] ?? 0);
                              
                          final valA = (diamondA is num) ? diamondA.toDouble() : double.tryParse(diamondA.toString()) ?? 0.0;
                          final valB = (diamondB is num) ? diamondB.toDouble() : double.tryParse(diamondB.toString()) ?? 0.0;
                          
                          return valB.compareTo(valA); // Descending
                        });
                      }
                      
                      // Calculate total
                      double totalDiamonds = 0;
                      for (var doc in docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final diamondValue = isEarning 
                            ? (data['earningDiamond'] ?? data['earningDiamonds'] ?? data['diamonds'] ?? 0)
                            : (data['diamonds'] ?? data['diamond'] ?? 0);
                        totalDiamonds += (diamondValue is num) ? diamondValue.toDouble() : double.tryParse(diamondValue.toString()) ?? 0.0;
                      }

                      return Column(
                        children: [
                          if (!isTopEarner) ...[
                            // Total Summary Card
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.pink.withValues(alpha: 0.5), AppColors.pink.withValues(alpha: 0.2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.pink.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                children: [
                                  Text(isEarning ? 'Total Agency Earnings' : 'Total Agency Wallet Diamonds', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.suit_diamond_fill, color: Colors.cyanAccent, size: 32),
                                      const SizedBox(width: 8),
                                      Text(
                                        totalDiamonds.toStringAsFixed(0),
                                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(isEarning ? 'Earnings Details' : 'Wallet Details', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],

                          if (docs.isEmpty)
                            Expanded(
                              child: Center(
                                child: Text(isEarning ? 'No host earnings found.' : 'No host wallets found.', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                physics: const BouncingScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final name = data['displayName'] ?? data['name'] ?? 'Unknown';
                                  final displayId = data['displayId'] ?? 'N/A';
                                  final photoUrl = data['photoUrl'] as String?;
                                  final displayDiamond = isEarning 
                                      ? (data['earningDiamond'] ?? data['earningDiamonds'] ?? data['diamonds'] ?? 0)
                                      : (data['diamonds'] ?? data['diamond'] ?? 0);
                                  
                                  Widget rankWidget = const SizedBox.shrink();
                                  if (isTopEarner) {
                                    if (index == 0) {
                                      rankWidget = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(16)),
                                        child: const Text('Rank 1 👑', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                                      );
                                    } else if (index == 1) {
                                      rankWidget = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(16)),
                                        child: const Text('Rank 2', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                      );
                                    } else if (index == 2) {
                                      rankWidget = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(color: Colors.orange.shade300, borderRadius: BorderRadius.circular(16)),
                                        child: const Text('Rank 3', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                      );
                                    } else {
                                      rankWidget = Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text('#${index + 1}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                                      );
                                    }
                                  }
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isTopEarner && index == 0 ? Colors.amber.withValues(alpha: 0.5) : AppColors.pink.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                          child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  rankWidget,
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'ID: $displayId',
                                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            const Icon(CupertinoIcons.suit_diamond_fill, color: Colors.cyanAccent, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$displayDiamond',
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
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
