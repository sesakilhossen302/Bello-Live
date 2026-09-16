import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(
        child: Text('Please login to view skins', style: TextStyle(color: Colors.white70)),
      );
    }

    final bagStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bag')
        .snapshots();

    final storeStream = FirebaseFirestore.instance
        .collection('store')
        .where('category', isEqualTo: 'RoomSkin')
        .snapshots();

    return StreamBuilder<List<RoomSkin>>(
      stream: Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<RoomSkin>>(
        bagStream,
        storeStream,
        (bagSnapshot, storeSnapshot) {
          final now = DateTime.now();
          final Map<String, RoomSkin> uniqueSkins = {};

          // 1. Process free skins from the store first
          for (var doc in storeSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final isActive = data['isActive'] ?? false;
            final price = data['price'] ?? 0;
            final tier = (data['tier'] ?? '').toString().toLowerCase();

            if (isActive && (price == 0 || tier == 'free')) {
              final skin = RoomSkin.fromFirestore(doc.id, data);
              if (skin.url.isNotEmpty) {
                uniqueSkins[skin.url] = skin;
              }
            }
          }

          // 2. Process user's bag (so user-owned skins can overwrite or add to the list)
          for (var doc in bagSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final category = (data['category'] ?? '').toString().toLowerCase();
            if (!category.contains('skin') && !category.contains('room')) continue;

            final expiresAt = data['expiresAt'] as Timestamp?;
            if (expiresAt != null && expiresAt.toDate().isBefore(now)) continue;

            final skin = RoomSkin.fromFirestore(doc.id, data);
            if (skin.url.isNotEmpty) {
              uniqueSkins[skin.url] = skin;
            }
          }

          return uniqueSkins.values.toList();
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading skins', style: TextStyle(color: Colors.white70)),
          );
        }

        final skins = snapshot.data ?? [];

        if (skins.isEmpty) {
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

          // Save to user profile and activeAddOns
          await ProfileService.savePreferredRoomSkin(skin.url);
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          if (currentUid != null) {
            await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
              'activeAddOns.Room Screen': {
                'imageUrl': skin.url,
                'expiresAt': null,
              },
            });
          }

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
      url: data['url'] ?? data['imageURL'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
