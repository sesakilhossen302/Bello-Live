import 'package:flutter/material.dart';
import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../theme/app_theme.dart';

class GameParticipant {
  final String userId;
  final String userName;
  final String? userPicture;

  GameParticipant({required this.userId, required this.userName, this.userPicture});

  /// Creates a [GameParticipant] from a Map (like from Firestore).
  factory GameParticipant.fromMap(Map<String, dynamic> data) {
    return GameParticipant(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data.containsKey('userPicture') ? data['userPicture'] : null,
    );
  }
}

class GameParticipantsBottomSheet extends StatelessWidget {
  final List<GameParticipant> participants;
  final String currentUserId;

  const GameParticipantsBottomSheet({super.key, required this.participants, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    // Sort the list, putting the current user first, then alphabetically
    final sortedParticipants = List<GameParticipant>.from(participants);
    sortedParticipants.sort((a, b) {
      if (a.userId == currentUserId) return -1;
      if (b.userId == currentUserId) return 1;
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

  Widget _buildParticipantTile(GameParticipant participant) {
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
              child: IgnorePointer(child: ActiveFrameWidget(userId: participant.userId, size: 52)),
            ),
          ],
        ),
      ),
      title: Text(
        participant.userName,
        style: TextStyle(
          color: isCurrentUser ? Colors.amber : Colors.white, // Highlight user
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: isCurrentUser ? const Text("You", style: TextStyle(color: Colors.white70)) : null,
    );
  }
}

/// Helper function to show the bottom sheet
void showGameParticipantsBottomSheet(
  BuildContext context, {
  required List<GameParticipant> participants,
  required String currentUserId,
}) {
  showModalBottomSheet(
    context: context,
    // Using your app's theme color from the gradient
    backgroundColor: AppColors.pinkDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: GameParticipantsBottomSheet(participants: participants, currentUserId: currentUserId),
      );
    },
  );
}
