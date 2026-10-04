import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'gift_image_widget.dart';

/// A StatefulWidget that securely fetches and caches the user's active frame
class ActiveFrameWidget extends StatefulWidget {
  final String userId;
  final double size;

  const ActiveFrameWidget({super.key, required this.userId, required this.size});

  @override
  State<ActiveFrameWidget> createState() => _ActiveFrameWidgetState();
}

class _ActiveFrameWidgetState extends State<ActiveFrameWidget> {
  late Future<DocumentSnapshot> _frameFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future so it doesn't refetch on every UI tick/animation rebuild
    _frameFuture = FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _frameFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        // Check for VIP / VVIP badge first
        final vipStr = (data['vip'] ?? data['vipType'] ?? '').toString().toLowerCase();
        final pkgStr = (data['activePackage'] ?? data['package'] ?? '').toString().toLowerCase();
        final bool isVvip = data['isVvip'] == true ||
            vipStr.contains('vvip') ||
            pkgStr.contains('vvip') ||
            pkgStr.contains('royal') ||
            pkgStr.contains('king');
        final bool isVip = isVvip ||
            data['isVip'] == true ||
            vipStr.contains('vip') ||
            pkgStr.contains('vip') ||
            pkgStr.contains('queen') ||
            pkgStr.contains('crown');

        if (isVvip) {
          return SizedBox(
            width: widget.size * 1.35,
            height: widget.size * 1.35,
            child: Image.asset(
              'assets/images/VVIP PNG.png',
              fit: BoxFit.contain,
            ),
          );
        } else if (isVip) {
          return SizedBox(
            width: widget.size * 1.35,
            height: widget.size * 1.35,
            child: Image.asset(
              'assets/images/VIP PNG.png',
              fit: BoxFit.contain,
            ),
          );
        }

        final activeAddOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};
        String? validFrameUrl;
        final frameData = activeAddOns['Frame'] as Map<String, dynamic>?;

        if (frameData != null) {
          final expiry = frameData['expiresAt'] as Timestamp?;
          if (expiry == null || expiry.toDate().isAfter(DateTime.now().toUtc())) {
            validFrameUrl = frameData['imageUrl'] as String?;
          }
        }

        if (validFrameUrl != null && validFrameUrl.isNotEmpty) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: MyImageWidget(
              imageUrl: validFrameUrl,
              fit: BoxFit.contain,
              playAudio: false, // Mute the frame in these overlays
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}