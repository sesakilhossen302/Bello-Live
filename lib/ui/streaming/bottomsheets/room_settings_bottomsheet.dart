import 'package:flutter/material.dart';

import '../../../data/remote/firebase/room_services.dart';

/// A bottom sheet that displays room settings for the host.
class RoomSettingsBottomSheet extends StatefulWidget {
  final String roomId;
  final bool initialMoveAllowed;

  const RoomSettingsBottomSheet({
    super.key,
    required this.roomId,
    required this.initialMoveAllowed,
  });

  @override
  State<RoomSettingsBottomSheet> createState() =>
      _RoomSettingsBottomSheetState();
}

class _RoomSettingsBottomSheetState extends State<RoomSettingsBottomSheet> {
  late bool _isMoveAllowed;

  @override
  void initState() {
    super.initState();
    _isMoveAllowed = widget.initialMoveAllowed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Header ---
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Room Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),

        // --- Settings List ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SwitchListTile(
            title: const Text(
              'Allow Seat Change',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Allow participants to move between empty seats.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            value: _isMoveAllowed,
            onChanged: (bool newValue) async {
              // Update UI immediately for responsiveness
              setState(() {
                _isMoveAllowed = newValue;
              });
              // Call the service to update Firestore
              try {
                await RoomService.toggleMoveAllowed(widget.roomId, newValue);
              } catch (e) {
                // If the update fails, revert the switch and show an error
                if (mounted) {
                  setState(() {
                    _isMoveAllowed = !newValue;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating setting: $e')),
                  );
                }
              }
            },
            activeThumbColor: Colors.pink,
          ),
        ),
      ],
    );
  }
}

/// A top-level function to display the room settings bottom sheet.
void showRoomSettingsBottomSheet(
  BuildContext context, {
  required String roomId,
  required bool isMoveAllowed,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: RoomSettingsBottomSheet(
          roomId: roomId,
          initialMoveAllowed: isMoveAllowed,
        ),
      );
    },
  );
}
