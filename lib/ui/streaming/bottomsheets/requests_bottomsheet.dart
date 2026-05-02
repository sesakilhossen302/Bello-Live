import 'package:flutter/material.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/room_services.dart';
import '../audio_room_page.dart';

class RequestsBottomSheet extends StatefulWidget {
  final List<dynamic> initialCoHostRequests;
  final List<dynamic> initialSpeakerRequests;
  final String roomID;
  final bool initialMoveAllowed;
  final bool initialSeatApprovalRequired;

  const RequestsBottomSheet({
    super.key,
    required this.initialCoHostRequests,
    required this.initialSpeakerRequests,
    required this.roomID,
    required this.initialMoveAllowed,
    required this.initialSeatApprovalRequired,
  });

  @override
  State<RequestsBottomSheet> createState() => _RequestsBottomSheetState();
}

class _RequestsBottomSheetState extends State<RequestsBottomSheet> {
  late List<dynamic> _coHostRequests;
  late List<dynamic> _speakerRequests;
  late bool _isMoveAllowed;
  late bool _isSeatApprovalRequired;

  @override
  void initState() {
    super.initState();
    _coHostRequests = List.from(widget.initialCoHostRequests);
    _speakerRequests = List.from(widget.initialSpeakerRequests);
    _isMoveAllowed = widget.initialMoveAllowed;
    _isSeatApprovalRequired = widget.initialSeatApprovalRequired;
  }

  Widget _buildRequestTile({
    required dynamic request,
    required String subtitle,
    required Future<void> Function() onApprove,
    required VoidCallback onStateChange,
  }) {
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: request.userPicture != null ? NetworkImage(request.userPicture!) : null,
              child: request.userPicture == null ? const Icon(Icons.person) : null,
            ),
            // Overlay the Frame (40 * 1.3 = 52)
            Positioned(
              width: 52,
              height: 52,
              child: IgnorePointer(child: ActiveFrameWidget(userId: request.userId, size: 52)),
            ),
          ],
        ),
      ),
      title: AutoScrollText(
        alignment: Alignment.centerLeft,
        text: request.userName,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            child: const Text('Reject', style: TextStyle(color: Colors.white70)),
            onPressed: () async {
              try {
                if (request is CoHostRequest) {
                  await RoomService.rejectCoHostRequest(widget.roomID, request.requestId);
                } else if (request is SpeakerRequest) {
                  await RoomService.rejectSpeakerRequest(widget.roomID, request.requestId);
                }
              } catch (e) {
                debugPrint("Error rejecting request: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                }
              }
              setState(onStateChange);
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              try {
                await onApprove();
                setState(onStateChange);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Helper to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCoHostRequests = _coHostRequests.isNotEmpty;
    final bool hasSpeakerRequests = _speakerRequests.isNotEmpty;
    final bool hasAnyRequests = hasCoHostRequests || hasSpeakerRequests;

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Room Settings',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SwitchListTile(
            title: const Text('Allow Seat Change', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'Allow speakers to move between empty seats.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            value: _isMoveAllowed,
            onChanged: (bool newValue) async {
              setState(() {
                _isMoveAllowed = newValue;
              });
              try {
                await RoomService.toggleMoveAllowed(widget.roomID, newValue);
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isMoveAllowed = !newValue;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating setting: $e')));
                }
              }
            },
            activeThumbColor: Colors.pink,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SwitchListTile(
            title: const Text('Lock seats', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'If off, guests can take empty seats directly.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            value: _isSeatApprovalRequired,
            onChanged: (bool newValue) async {
              setState(() {
                _isSeatApprovalRequired = newValue;
              });
              try {
                await RoomService.toggleSeatApprovalRequired(widget.roomID, newValue);
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isSeatApprovalRequired = !newValue;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating setting: $e')));
                }
              }
            },
            activeThumbColor: Colors.pink,
          ),
        ),

        if (hasCoHostRequests) ...[
          const Divider(color: Colors.white24, height: 1),
          _buildSectionHeader("Co-Host Requests (${_coHostRequests.length})"),
          ..._coHostRequests.map(
            (request) => _buildRequestTile(
              request: request,
              subtitle: 'Wants to be a co-host',
              onApprove: () => RoomService.approveCoHostRequest(widget.roomID, request.requestId, request.userId),
              onStateChange: () => _coHostRequests.remove(request),
            ),
          ),
          if (hasSpeakerRequests) const Divider(color: Colors.white24, height: 1),
        ],

        if (hasSpeakerRequests) ...[
          if (!hasCoHostRequests) const Divider(color: Colors.white24, height: 1),
          _buildSectionHeader("Speaker Requests (${_speakerRequests.length})"),
          ..._speakerRequests.map(
            (request) => _buildRequestTile(
              request: request,
              subtitle: 'Wants to join a chair',
              onApprove: () => RoomService.approveSpeakerRequest(widget.roomID, request.requestId, request.userId),
              onStateChange: () => _speakerRequests.remove(request),
            ),
          ),
        ],

        if (!hasAnyRequests)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Text("No pending requests", style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}

void showAllRequestsBottomSheet(
  BuildContext context, {
  required List<dynamic> coHostRequests,
  required List<dynamic> speakerRequests,
  required String roomID,
  required bool isMoveAllowed,
  required bool isSeatApprovalRequired,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.7,
      child: RequestsBottomSheet(
        initialCoHostRequests: coHostRequests,
        initialSpeakerRequests: speakerRequests,
        roomID: roomID,
        initialMoveAllowed: isMoveAllowed,
        initialSeatApprovalRequired: isSeatApprovalRequired,
      ),
    ),
  );
}
