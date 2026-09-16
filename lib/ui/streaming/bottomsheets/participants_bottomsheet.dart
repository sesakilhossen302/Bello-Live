import 'package:flutter/material.dart';
import 'package:picture_live/data/remote/firebase/profile_services.dart';
import 'package:picture_live/ui/live_streaming/bottomsheets/profile_info_bottomsheet.dart';
import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../core/widgets/auto_scroll_text.dart';
import '../audio_room_page.dart';
import '../../../data/remote/firebase/room_services.dart';

/// A bottom sheet that displays a list of all participants in the room.
class ParticipantsBottomSheet extends StatelessWidget {
  final List<RoomParticipant> participants;
  final String currentUserId;
  final String hostId;
  final String roomId;
  final bool isCurrentUserAdmin;

  const ParticipantsBottomSheet({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.hostId,
    required this.roomId,
    this.isCurrentUserAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out host from participants list
    final filteredParticipants = participants
        .where((p) => p.userId != hostId && p.seatNo != 0)
        .toList();

    // Sort the list based on role priority: Co-host > Speaker > Listener
    filteredParticipants.sort((a, b) {
      int getRoleValue(RoomParticipant p) {
        if (p.isCoHost) return 1; // Co-host
        if (p.seatNo > 0) return 2; // Speaker
        return 3; // Listener
      }

      final roleCompare = getRoleValue(a).compareTo(getRoleValue(b));
      if (roleCompare != 0) return roleCompare;
      return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });

    return Column(
      children: [
        // --- Header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: AutoScrollText(
            alignment: Alignment.centerLeft,
            text: 'Participants (${filteredParticipants.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        // --- Participants List ---
        Expanded(
          child: filteredParticipants.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No participants yet',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredParticipants.length,
                  itemBuilder: (context, index) {
                    final participant = filteredParticipants[index];
                    // Pass context to the tile builder
                    return _buildParticipantTile(context, participant);
                  },
                ),
        ),
      ],
    );
  }

  /// Builds a single row for a participant in the list.
  Widget _buildParticipantTile(BuildContext context, RoomParticipant participant) {
    // Determine the role for the subtitle
    String role = 'Listener';
    if (participant.seatNo == 0) {
      role = 'Host';
    } else if (participant.isCoHost) {
      role = 'Co-host';
    } else if (participant.seatNo > 0 || participant.isApprovedSpeaker) {
      role = 'Speaker';
    }

    final bool isCurrentUser = participant.userId == currentUserId;

    return ListTile(
      // --- ADDED ONTAP ---
      onTap: () {
        // Close this bottom sheet first
        Navigator.of(context).pop();
        // Show the new profile bottom sheet
        showProfileInfoBottomSheet(context, userId: participant.userId, hostId: hostId, roomId: roomId);
      },
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: participant.userPicture != null && participant.userPicture!.isNotEmpty
                  ? NetworkImage(participant.userPicture!)
                  : null,
              child: participant.userPicture == null || participant.userPicture!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            // Overlay the Frame (40 * 1.3 = 52)
            Positioned(
              width: 52,
              height: 52,
              child: IgnorePointer(child: ActiveFrameWidget(userId: participant.userId, size: 52)),
            ),
          ],
        ),
      ),
      title: Text(
        participant.userName,
        style: TextStyle(
          color: isCurrentUser ? Colors.pink : Colors.white,
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(role, style: const TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCurrentUser)
            StreamBuilder<bool>(
              stream: ProfileService.isFollowing(participant.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                }

                final bool isFollowing = snapshot.data ?? false;

                return GestureDetector(
                  onTap: () async {
                    try {
                      if (isFollowing) {
                        await ProfileService.unfollowUser(participant.userId);
                      } else {
                        await ProfileService.followUser(participant.userId);
                      }
                    } catch (e) {
                      debugPrint('Error following/unfollowing user: $e');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFollowing ? Colors.grey.shade800 : Colors.pink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          if ((currentUserId == hostId || isCurrentUserAdmin) && participant.userId != hostId && participant.userId != currentUserId) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF2d1b2b),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'mute') {
                  await RoomService.muteParticipant(roomId, participant.userId, !participant.isMuted);
                } else if (value == 'kick') {
                  _confirmAction(context, 'Kick', participant.userName, () => RoomService.kickParticipant(roomId, participant.userId));
                } else if (value == 'block') {
                  _showBlockOptions(context, participant.userName, participant.userId);
                } else if (value == 'lock') {
                  await RoomService.lockParticipant(roomId, participant.userId, !participant.isLocked);
                } else if (value == 'add_to_call') {
                  try {
                    await RoomService.inviteOrRemoveParticipantFromCall(roomId, participant.userId, true);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${participant.userName} added to call.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                } else if (value == 'remove_from_call') {
                  try {
                    await RoomService.inviteOrRemoveParticipantFromCall(roomId, participant.userId, false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${participant.userName} removed from call.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                if (!participant.isApprovedSpeaker && !participant.isCoHost)
                  const PopupMenuItem(
                    value: 'add_to_call',
                    child: Row(
                      children: [
                        Icon(Icons.call, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Seat on Call', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                if (participant.isApprovedSpeaker && !participant.isCoHost)
                  const PopupMenuItem(
                    value: 'remove_from_call',
                    child: Row(
                      children: [
                        Icon(Icons.call_end, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Remove from Call', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        participant.isMuted ? Icons.mic_off : Icons.mic,
                        color: participant.isMuted ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        participant.isMuted ? 'Unmute' : 'Mute',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'kick',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Kick', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_flipped, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Block', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(
                        participant.isLocked ? Icons.lock_open : Icons.lock,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        participant.isLocked ? 'Unlock' : 'Lock',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showBlockOptions(BuildContext context, String userName, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        title: Text('Block $userName', style: const TextStyle(color: Colors.white)),
        content: const Text('Select block duration:', style: TextStyle(color: Colors.white70)),
        actions: [
          _blockOption(context, '5 Minute', userId, const Duration(minutes: 5)),
          _blockOption(context, '24 Hours', userId, const Duration(hours: 24)),
          _blockOption(context, '7 Days', userId, const Duration(days: 7)),
          _blockOption(context, 'Permanent', userId, null),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _blockOption(BuildContext context, String label, String userId, Duration? duration) {
    return TextButton(
      onPressed: () async {
        Navigator.pop(context);
        await RoomService.blockParticipant(roomId, userId, duration: duration);
      },
      child: Text(label, style: const TextStyle(color: Colors.pink)),
    );
  }

  void _confirmAction(BuildContext context, String action, String userName, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        title: Text('$action User', style: const TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to $action $userName?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await onConfirm();
            },
            child: Text(action, style: const TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }
}

void showParticipantsBottomSheet(
  BuildContext context, {
  required List<RoomParticipant> participants,
  required String currentUserId,
  required String hostId,
  required String roomId,
  bool isCurrentUserAdmin = false,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true, // Allows the sheet to take up more screen space
    builder: (context) {
      // Use 70% of the screen height to avoid covering the whole screen
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: ParticipantsBottomSheet(
          roomId: roomId,
          participants: participants,
          currentUserId: currentUserId,
          hostId: hostId,
          isCurrentUserAdmin: isCurrentUserAdmin,
        ),
      );
    },
  );
}
