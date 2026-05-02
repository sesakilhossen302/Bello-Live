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