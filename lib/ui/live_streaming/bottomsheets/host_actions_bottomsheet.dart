import 'package:flutter/material.dart';

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
            // Full width
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            // --- MODIFIED: Changed alignment to center ---
            alignment: Alignment.center,
            // --- END MODIFICATION ---
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: onPressed,
        ),
      );
    }

    // Placeholder function for actions
    void performAction(BuildContext context, String action) {
      // TODO: Implement actual host actions
      // e.g., VideoRoomService.kickUser(roomId, targetUserId);
      debugPrint('Host action: $action on $targetUserName ($targetUserId) in room $roomId');
      Navigator.of(context).pop(); // Close the sheet
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$action performed on $targetUserName.'), backgroundColor: Colors.green));
    }

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
          buildActionButton('Set Admin', Icons.security, () => performAction(context, 'Set Admin')),
          buildActionButton('Mute', Icons.mic_off, () => performAction(context, 'Mute')),
          buildActionButton('Chat Mute', Icons.no_sim, () => performAction(context, 'Chat Mute')),
          buildActionButton('Kick Out', Icons.exit_to_app, () => performAction(context, 'Kick Out')),
          const SizedBox(height: 16),
        ],
      ),
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
