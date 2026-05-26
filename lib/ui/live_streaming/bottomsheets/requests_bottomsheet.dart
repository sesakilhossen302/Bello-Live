import 'package:flutter/material.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../live_room_page.dart';

class LiveStreamJoinRequestsBottomSheet extends StatefulWidget {
  final List<JoinRequest> initialJoinRequests;
  final String roomID;
  final int currentGuestCount;

  const LiveStreamJoinRequestsBottomSheet({
    super.key,
    required this.initialJoinRequests,
    required this.roomID,
    required this.currentGuestCount,
  });

  @override
  State<LiveStreamJoinRequestsBottomSheet> createState() => _LiveStreamJoinRequestsBottomSheetState();
}

class _LiveStreamJoinRequestsBottomSheetState extends State<LiveStreamJoinRequestsBottomSheet> {
  late List<JoinRequest> _joinRequests;
  int _approvedCount = 0;

  @override
  void initState() {
    super.initState();
    _joinRequests = List.from(widget.initialJoinRequests);
  }

  Widget _buildRequestTile(BuildContext context, JoinRequest request) {
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
              backgroundImage: request.userPicture != null && request.userPicture!.isNotEmpty
                  ? NetworkImage(request.userPicture!)
                  : null,
              child: request.userPicture == null || request.userPicture!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
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
      subtitle: const Text('Wants to join the stream', style: TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              LiveStreamService.rejectJoinRequest(widget.roomID, request.requestId);
              setState(() {
                _joinRequests.remove(request);
              });
              if (_joinRequests.isEmpty) {
                Navigator.pop(context);
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (widget.currentGuestCount + _approvedCount >= 9) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maximum 10 people (including host) can join the call.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              LiveStreamService.approveJoinRequest(widget.roomID, request.requestId, request.userId);
              setState(() {
                _joinRequests.remove(request);
                _approvedCount++;
              });
              if (_joinRequests.isEmpty) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Join Requests (${_joinRequests.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: _joinRequests.isEmpty
              ? const Center(
                  child: Text('No pending requests', style: TextStyle(color: Colors.white70, fontSize: 16)),
                )
              : ListView.builder(
                  itemCount: _joinRequests.length,
                  itemBuilder: (context, index) {
                    final request = _joinRequests[index];
                    return _buildRequestTile(context, request);
                  },
                ),
        ),
      ],
    );
  }
}

void showLiveStreamJoinRequestsBottomSheet({
  required BuildContext context,
  required List<JoinRequest> joinRequests,
  required String roomID,
  required int currentGuestCount,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: LiveStreamJoinRequestsBottomSheet(
          initialJoinRequests: joinRequests,
          roomID: roomID,
          currentGuestCount: currentGuestCount,
        ),
      );
    },
  );
}
