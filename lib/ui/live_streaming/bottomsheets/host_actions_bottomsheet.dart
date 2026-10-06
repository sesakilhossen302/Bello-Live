import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../live_room_page.dart'; // To get LiveStreamParticipant

class HostActionsBottomSheet extends StatelessWidget {
  final String targetUserId;
  final String targetUserName;
  final String roomId;

  const HostActionsBottomSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    // Helper to create action buttons
    Widget buildActionButton(String title, IconData icon, VoidCallback onPressed, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        child: ElevatedButton.icon(
          icon: Icon(icon, color: color ?? Colors.white, size: 20),
          label: Text(title, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: onPressed,
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: LiveStreamService.getParticipantStream(roomId, targetUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Manage $targetUserName',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('User is not currently in the room', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final participant = LiveStreamParticipant.fromRTDB(snapshot.data!.snapshot.key!, data);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.manage_accounts, color: Colors.pinkAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Manage $targetUserName',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),

              // Make Admin / Remove Admin
              buildActionButton(
                participant.isAdmin ? 'Remove Admin Role' : 'Make Room Admin',
                participant.isAdmin ? Icons.shield_outlined : Icons.shield,
                () async {
                  try {
                    await LiveStreamService.setAdmin(roomId, targetUserId, !participant.isAdmin);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(participant.isAdmin ? 'Removed admin role from $targetUserName' : 'Assigned admin role to $targetUserName'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                color: participant.isAdmin ? Colors.orangeAccent : Colors.cyanAccent,
              ),

              // Make / Remove Co-Host
              buildActionButton(
                participant.isCoHost ? 'Remove Co-Host' : 'Make Co-Host',
                participant.isCoHost ? Icons.star_border : Icons.star,
                () async {
                  try {
                    await LiveStreamService.setCoHost(roomId, targetUserId, !participant.isCoHost);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(participant.isCoHost ? 'Removed co-host role from $targetUserName' : 'Assigned co-host role to $targetUserName'),
                          backgroundColor: Colors.purpleAccent,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                color: Colors.purpleAccent,
              ),

              // Transfer Host Role
              buildActionButton(
                'Transfer Host to $targetUserName',
                Icons.swap_horiz,
                () async {
                  try {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF2C132B),
                        title: const Text('Transfer Host', style: TextStyle(color: Colors.white)),
                        content: Text('Are you sure you want to transfer host role to $targetUserName?', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Transfer', style: TextStyle(color: Colors.pinkAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await LiveStreamService.transferHost(roomId, targetUserId, targetUserName, participant.userPicture);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transferred host to $targetUserName'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                color: Colors.amberAccent,
              ),

              // Invite to Call (if not on seat)
              if (!participant.isOnSeat)
                buildActionButton(
                  'Invite to Call',
                  Icons.add_call,
                  () async {
                    try {
                      await LiveStreamService.sendCallInvite(roomId, targetUserId, 'Host');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Call invite sent to $targetUserName')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),

              // Mute / Unmute Mic (if on seat)
              if (participant.isOnSeat)
                buildActionButton(
                  participant.isMuted ? 'Unmute Mic' : 'Mute Mic',
                  participant.isMuted ? Icons.mic : Icons.mic_off,
                  () async {
                    try {
                      await LiveStreamService.muteParticipant(roomId, targetUserId, !participant.isMuted);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(participant.isMuted ? 'Mic unmuted' : 'Mic muted')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),

              // Kick Out
              buildActionButton(
                'Kick Out of Room',
                Icons.exit_to_app,
                () async {
                  try {
                    await LiveStreamService.kickParticipant(roomId, targetUserId);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$targetUserName has been kicked out.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Top-level function to show the host actions bottom sheet.
void showHostActionsBottomSheet(
  BuildContext context, {
  required String targetUserId,
  required String targetUserName,
  required String roomId,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return HostActionsBottomSheet(targetUserId: targetUserId, targetUserName: targetUserName, roomId: roomId);
    },
  );
}
