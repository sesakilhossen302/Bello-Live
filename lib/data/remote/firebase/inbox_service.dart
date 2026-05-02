import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InboxService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sends a room invite to a list of user IDs
  static Future<void> sendRoomInvite({
    required List<String> receiverIds,
    required String roomId,
    required String roomHostName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();

    for (String receiverId in receiverIds) {
      final docRef = _firestore
          .collection('users')
          .doc(receiverId)
          .collection('inbox')
          .doc();

      batch.set(docRef, {
        'type': 'room_invite',
        'title': 'Room Invite',
        'message': '${currentUser.displayName ?? "Someone"} invited you to join $roomHostName\'s room!',
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Unknown',
        'senderPicture': currentUser.photoURL,
        'roomId': roomId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  }
}