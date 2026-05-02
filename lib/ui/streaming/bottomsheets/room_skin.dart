import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../data/remote/firebase/room_services.dart';

class RoomSkinSideSheet extends StatelessWidget {
  final String roomId;

  const RoomSkinSideSheet({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sheetWidth = screenWidth / 1.5;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: sheetWidth,
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a0a0a), Color(0xFF2d1b2b), Color(0xFF4a2c4a)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: Offset(-5, 0))],
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildSkinGrid()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Room Skins',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('room_skin').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading skins', style: TextStyle(color: Colors.white70)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.color_lens_outlined, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No skins available', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          );
        }

        final skins = snapshot.data!.docs
            .map((doc) => RoomSkin.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 9 / 16, // 9:16 aspect ratio
          ),
          itemCount: skins.length,
          itemBuilder: (context, index) {
            return _buildSkinItem(context, skins[index]);
          },
        );
      },
    );
  }

  Widget _buildSkinItem(BuildContext context, RoomSkin skin) {
    return GestureDetector(
      onTap: () async {
        try {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(child: CircularProgressIndicator(color: Colors.pink)),
          );

          // Update room background
          await RoomService.updateRoomBackground(roomId, skin.url);

          // NEW: Save to user profile
          await ProfileService.savePreferredRoomSkin(skin.url);

          // Close loading dialog
          if (context.mounted) Navigator.pop(context);

          // Close side sheet
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          // Close loading dialog if open
          if (context.mounted) Navigator.pop(context);
          // Show error
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: skin.url,
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, url, downloadProgress) => Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                      color: Colors.pink,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(child: Icon(Icons.broken_image, color: Colors.white.withValues(alpha: 0.5), size: 40)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showRoomSkinSideSheet(BuildContext context, String roomId) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Room Skins',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return RoomSkinSideSheet(roomId: roomId);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: child,
      );
    },
  );
}

// lib/models/room_skin.dart
class RoomSkin {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  RoomSkin({required this.id, required this.name, required this.url, required this.createdAt});

  factory RoomSkin.fromFirestore(String id, Map<String, dynamic> data) {
    return RoomSkin(
      id: id,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
