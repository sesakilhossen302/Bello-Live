import 'package:flutter/material.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../core/widgets/auto_scroll_text.dart';
import '../live_room_page.dart';

class LiveStreamParticipantsBottomSheet extends StatelessWidget {
  final List<LiveStreamParticipant> participants;
  final String currentUserId;
  final String hostId;

  const LiveStreamParticipantsBottomSheet({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.hostId,
  });

  @override
  Widget build(BuildContext context) {
    final sortedParticipants = List<LiveStreamParticipant>.from(participants);

    sortedParticipants.sort((a, b) {
      if (a.userId == hostId) return -1;
      if (b.userId == hostId) return 1;
      return a.userName.compareTo(b.userName);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Participants (${participants.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: sortedParticipants.length,
            itemBuilder: (context, index) {
              final participant = sortedParticipants[index];
              return _buildParticipantTile(participant);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantTile(LiveStreamParticipant participant) {
    final String role = participant.userId == hostId ? 'Host' : 'Guest';
    final bool isCurrentUser = participant.userId == currentUserId;

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
              child: IgnorePointer(
                child: ActiveFrameWidget(userId: participant.userId, size: 52),
              ),
            ),
          ],
        ),
      ),
      title: AutoScrollText(
        alignment: Alignment.centerLeft,
        text: participant.userName,
        style: TextStyle(
          color: isCurrentUser ? Colors.pink : Colors.white,
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(role, style: const TextStyle(color: Colors.white70)),
    );
  }
}

void showLiveStreamParticipantsBottomSheet(
    BuildContext context, {
      required List<LiveStreamParticipant> participants,
      required String currentUserId,
      required String hostId,
    }) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: LiveStreamParticipantsBottomSheet(
          participants: participants,
          currentUserId: currentUserId,
          hostId: hostId,
        ),
      );
    },
  );
}