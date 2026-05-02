import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // 👉 ADDED to fetch active rooms directly
import 'package:flutter/material.dart';
import 'package:picture_live/data/remote/firebase/live_streaming_services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../theme/app_theme.dart';

/// Shows the PK invite bottom sheet
void showInvitePKBottomSheet(
  BuildContext context, {
  required List<PKInvite> pendingInvites,
  required String currentRoomId,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return InvitePKBottomSheet(
            scrollController: scrollController,
            pendingInvites: pendingInvites,
            currentRoomId: currentRoomId,
          );
        },
      );
    },
  );
}

/// Bottom sheet widget for inviting users to PK battles
class InvitePKBottomSheet extends StatefulWidget {
  final ScrollController scrollController;
  final List<PKInvite> pendingInvites;
  final String currentRoomId;

  const InvitePKBottomSheet({
    super.key,
    required this.scrollController,
    required this.pendingInvites,
    required this.currentRoomId,
  });

  @override
  State<InvitePKBottomSheet> createState() => _InvitePKBottomSheetState();
}

class _InvitePKBottomSheetState extends State<InvitePKBottomSheet> {
  late Future<List<SimpleUser>> _mutualsFuture;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _mutualsFuture = _loadMutualsWithRoomStatus();
  }

  /// FIX: Fetch all active rooms safely and filter locally to avoid Firebase Index Drops
  Future<List<SimpleUser>> _loadMutualsWithRoomStatus() async {
    try {
      // 1. Get mutual friends
      final mutuals = await ProfileService.getMutualsList(_currentUserId);
      if (mutuals.isEmpty) return [];

      // Create a quick lookup map of mutual friends by their ID
      final mutualsMap = {for (var m in mutuals) m.id: m};

      // 2. Fetch all live streams SAFELY without using orderByChild
      final activeRoomsSnapshot = await FirebaseDatabase.instance.ref('live_streams').get();
      if (!activeRoomsSnapshot.exists) return [];

      final activeRooms = Map<dynamic, dynamic>.from(activeRoomsSnapshot.value as Map);
      final List<SimpleUser> availableHosts = [];

      // 3. Cross-reference active hosts with our friends list
      for (final entry in activeRooms.entries) {
        final roomId = entry.key.toString();
        if (roomId == widget.currentRoomId) continue; // Skip your own room

        if (entry.value is! Map) continue;
        final roomData = Map<dynamic, dynamic>.from(entry.value as Map);

        // Ensure the room is actually active
        if (roomData['isActive'] != true) continue;

        final hostId = roomData['hostId']?.toString() ?? '';

        // If this active host is our friend
        if (mutualsMap.containsKey(hostId)) {
          // Make sure they are not ALREADY in a PK
          final pkState = roomData['pkState'];
          bool isAlreadyInPk = false;
          if (pkState is Map) {
            isAlreadyInPk = pkState['isPK'] == true;
          }

          if (!isAlreadyInPk) {
            final friend = mutualsMap[hostId]!;
            availableHosts.add(
              SimpleUser(id: friend.id, name: friend.name, pictureUrl: friend.pictureUrl, currentRoomId: roomId),
            );
          }
        }
      }

      return availableHosts;
    } catch (e) {
      debugPrint('Error loading mutuals: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Invite PK',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white24, height: 1, thickness: 1),
          if (widget.pendingInvites.isNotEmpty) _buildReceivedInvitesSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Text(
                  'Available to Invite',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(child: _buildAvailableHostsList()),
        ],
      ),
    );
  }

  Widget _buildReceivedInvitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Received Invites',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.pendingInvites.length,
          itemBuilder: (context, index) => _buildReceivedInviteRow(widget.pendingInvites[index]),
        ),
        const Divider(color: Colors.white24, height: 1, thickness: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildReceivedInviteRow(PKInvite invite) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: (invite.senderHostPicture != null && invite.senderHostPicture!.isNotEmpty)
                ? CachedNetworkImageProvider(invite.senderHostPicture!)
                : null,
            child: (invite.senderHostPicture == null || invite.senderHostPicture!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AutoScrollText(
              text: invite.senderHostName,
              alignment: AlignmentGeometry.centerLeft,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _rejectInvite(invite),
            child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => _acceptInvite(invite),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableHostsList() {
    return FutureBuilder<List<SimpleUser>>(
      future: _mutualsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        if (snapshot.hasError) {
          return _EmptyListWidget(icon: Icons.error_outline, message: 'Failed to load list: ${snapshot.error}');
        }

        //  The list is already fully filtered by our new Future logic above!
        final availableHosts = snapshot.data ?? [];

        if (availableHosts.isEmpty) {
          return const _EmptyListWidget(
            icon: Icons.people_outline,
            message: 'No friends are currently hosting available rooms.',
          );
        }

        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: availableHosts.length,
          itemBuilder: (context, index) => _buildUserRow(availableHosts[index]),
        );
      },
    );
  }

  Widget _buildUserRow(SimpleUser user) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: (user.pictureUrl != null && user.pictureUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(user.pictureUrl!)
                : null,
            child: (user.pictureUrl == null || user.pictureUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AutoScrollText(
              text: user.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showTimerSelectionDialog(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimerSelectionDialog(SimpleUser user) async {
    final int? selectedDuration = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Set PK Duration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDurationOption(context, '5 Minutes', 5),
            _buildDurationOption(context, '7 Minutes', 7),
            _buildDurationOption(context, '10 Minutes', 10),
          ],
        ),
      ),
    );

    if (selectedDuration != null && mounted) {
      await _sendInvite(user, selectedDuration);
    }
  }

  Widget _buildDurationOption(BuildContext context, String label, int minutes) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.of(context).pop(minutes),
    );
  }

  Future<void> _sendInvite(SimpleUser user, int durationInMinutes) async {
    try {
      await LiveStreamService.sendPKInvite(
        senderRoomId: widget.currentRoomId,
        receiverUserId: user.id,
        durationInMinutes: durationInMinutes,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PK invite sent!'), backgroundColor: Colors.pink));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send invite: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _acceptInvite(PKInvite invite) async {
    await LiveStreamService.acceptPKInvite(widget.currentRoomId, invite);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PK accepted with ${invite.senderHostName}!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _rejectInvite(PKInvite invite) async {
    await LiveStreamService.rejectPKInvite(widget.currentRoomId, invite);
  }
}

class _EmptyListWidget extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyListWidget({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PKInvite {
  final String id;
  final String senderRoomId;
  final String senderHostId;
  final String senderHostName;
  final String? senderHostPicture;
  final String receiverRoomId;
  final String receiverHostId;
  final int durationInMinutes;
  final bool isRandom;

  PKInvite({
    required this.id,
    required this.senderRoomId,
    required this.senderHostId,
    required this.senderHostName,
    this.senderHostPicture,
    required this.receiverRoomId,
    required this.receiverHostId,
    required this.durationInMinutes,
    this.isRandom = false,
  });

  factory PKInvite.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return PKInvite(
      id: key,
      senderRoomId: data['senderRoomId'] ?? '',
      senderHostId: data['senderHostId'] ?? '',
      senderHostName: data['senderHostName'] ?? 'Unknown',
      senderHostPicture: data['senderHostPicture'],
      receiverRoomId: data['receiverRoomId'] ?? '',
      receiverHostId: data['receiverHostId'] ?? '',
      durationInMinutes: data['durationInMinutes'] ?? 5,
      isRandom: data['isRandom'] ?? false,
    );
  }

  factory PKInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PKInvite(
      id: doc.id,
      senderRoomId: data['senderRoomId'] ?? '',
      senderHostId: data['senderHostId'] ?? '',
      senderHostName: data['senderHostName'] ?? 'Unknown Host',
      senderHostPicture: data['senderHostPicture'],
      receiverRoomId: data['receiverRoomId'] ?? '',
      receiverHostId: data['receiverHostId'] ?? '',
      durationInMinutes: data['durationInMinutes'] ?? 5,
      isRandom: data['isRandom'] ?? false,
    );
  }
}

class SimpleUser {
  final String id;
  final String name;
  final String? pictureUrl;
  final String? currentRoomId;

  SimpleUser({required this.id, required this.name, this.pictureUrl, this.currentRoomId});
}
