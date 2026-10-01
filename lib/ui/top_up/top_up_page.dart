import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/remote/firebase/profile_services.dart';

class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final String defaultMessage = "Hello, I want to purchase Coins for my ProLive account.";

  String _formatCoins(int number) {
    if (number >= 1000000) {
      final millions = number / 1000000;
      return '${millions.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (number >= 1000) {
      final thousands = number / 1000;
      return '${thousands.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    return number.toString();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String rawNumber) async {
    String cleanNumber = rawNumber.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '88$cleanNumber';
    }

    final String message = Uri.encodeComponent(defaultMessage);
    final Uri appUrl = Uri.parse('whatsapp://send?phone=$cleanNumber&text=$message');
    final Uri webUrl = Uri.parse('https://wa.me/$cleanNumber?text=$message');

    try {
      bool launched = await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          throw Exception("Could not launch");
        }
      }
    } catch (e) {
      try {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open WhatsApp. Please check if it's installed."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              color: const Color(0xFF5A189A),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).topUp,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Real-time Coins Display Card
            StreamBuilder<int>(
              stream: ProfileService.getCurrentUserBalanceStream(),
              builder: (context, snapshot) {
                final int coinsCount = snapshot.data ?? 0;
                return Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E42),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Current Coins Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A189A).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.diamond_rounded,
                              color: Color(0xFF5A189A),
                              size: 38,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(scale: animation, child: child);
                              },
                              child: Text(
                                _formatCoins(coinsCount),
                                key: ValueKey<String>(_formatCoins(coinsCount)),
                                style: const TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // WhatsApp Agents List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('topup_agents')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF5A189A)),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No active agents available.",
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  final agents = snapshot.data!.docs;

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: agents.length,
                    itemBuilder: (context, index) {
                      final data = agents[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unknown Agent';
                      final displayId = data['displayId'] ?? 'N/A';
                      final photo = data['photo'] as String?;
                      final whatsappNumber = data['whatsappNumber'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E42),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF25D366),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: photo != null && photo.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: photo,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) => const Icon(
                                              CupertinoIcons.person_solid,
                                              color: Colors.grey,
                                              size: 30,
                                            ),
                                          )
                                        : const Icon(
                                            CupertinoIcons.person_solid,
                                            color: Colors.grey,
                                            size: 30,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.verified, color: Color(0xFFFFB300), size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ID: $displayId',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // WhatsApp Number Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF162B5B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone, color: Color(0xFF25D366), size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    whatsappNumber,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // WhatsApp Button
                            GestureDetector(
                              onTap: () {
                                if (whatsappNumber.isNotEmpty) {
                                  _launchWhatsApp(whatsappNumber);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat, color: Colors.white, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Message on WhatsApp',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    );
  }
}
