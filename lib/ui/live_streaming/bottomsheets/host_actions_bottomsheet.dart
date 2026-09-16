import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../data/remote/firebase/room_services.dart';
import '../../streaming/audio_room_page.dart'; // To get RoomParticipant

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
    Widget buildActionButton(String title, IconData icon, VoidCallback onPressed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white),
          label: Text(title, style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: onPressed,
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: RoomService.getParticipantStream(roomId, targetUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return const SafeArea(
            child: SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: Colors.pink)),
            ),
          );
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final participant = RoomParticipant.fromRTDB(snapshot.data!.snapshot.key!, data);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Manage $targetUserName',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              buildActionButton(
                participant.isAdmin ? 'Remove Admin' : 'Set Admin',
                participant.isAdmin ? Icons.security_outlined : Icons.security,
                () async {
                  try {
                    await RoomService.setAdmin(roomId, targetUserId, !participant.isAdmin);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(participant.isAdmin ? 'Removed admin.' : 'Set as admin.')),
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
              buildActionButton(
                participant.isMuted ? 'Unmute' : 'Mute',
                participant.isMuted ? Icons.mic : Icons.mic_off,
                () async {
                  try {
                    await RoomService.muteParticipant(roomId, targetUserId, !participant.isMuted);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(participant.isMuted ? 'Unmuted.' : 'Muted.')),
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
              buildActionButton(
                participant.isChatMuted ? 'Unmute Chat' : 'Chat Mute',
                participant.isChatMuted ? Icons.speaker_notes : Icons.no_sim,
                () async {
                  try {
                    await RoomService.chatMuteParticipant(roomId, targetUserId, !participant.isChatMuted);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(participant.isChatMuted ? 'Chat unmuted.' : 'Chat muted.')),
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
              buildActionButton('Kick Out', Icons.exit_to_app, () async {
                try {
                  await RoomService.kickParticipant(roomId, targetUserId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kicked out.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }),
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
    builder: (context) {
      return HostActionsBottomSheet(targetUserId: targetUserId, targetUserName: targetUserName, roomId: roomId);
    },
  );
}
