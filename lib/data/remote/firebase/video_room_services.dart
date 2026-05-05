import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service class for managing video rooms using Firebase RTDB and Firestore
class VideoRoomService {
  // Firebase Instances
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection & Reference Paths
  static final _usersCollection = _firestore.collection('users');
  static final DatabaseReference _roomsRef = _database.ref('video_rooms');
  static final DatabaseReference _connectedRef = _database.ref('.info/connected');

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  /// Creates a new video room and returns the room ID
  static Future<String> createRoom() async {
    final user = _auth.currentUser!;
    final roomRef = _roomsRef.push();
    final roomId = roomRef.key!;

    final userDoc = await _usersCollection.doc(user.uid).get();
    if (!userDoc.exists) {
      throw Exception("User profile not found. Cannot create room.");
    }

    final userData = userDoc.data() as Map<String, dynamic>;
    final String hostName = userData['displayName'] ?? 'Anonymous';
    final String? hostPicture = userData['photoUrl'];
    final String displayId = userData['displayId'] ?? '';
    final String hostCountry = userData['country'] ?? 'Unknown';

    await roomRef.set({
      'hostId': user.uid,
      'hostDisplayId': displayId,
      'hostName': hostName,
      'hostPicture': hostPicture,
      'hostCountry': hostCountry,
      'createdAt': ServerValue.timestamp,
      'isActive': true,
      'participantCount': 1,
      'onCallCount': 1,
      'isLocked': false,
      'password': null,
    });

    final participantRef = roomRef.child('participants/${user.uid}');
    await participantRef.set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': hostName,
      'userPicture': hostPicture,
      'joinedAt': ServerValue.timestamp,
      'isOnline': true,
      'isMuted': false,
      'isCameraOn': true,
      'onCall': true,
    });

    await _setupPresence(roomId, user.uid, isOnCall: true, isHost: true);

    return roomId;
  }

  /// Gets a stream of all active rooms
  static Stream<DatabaseEvent> getAllRooms() {
    return _roomsRef.orderByChild('isActive').equalTo(true).onValue;
  }

  /// Gets room information for a specific room ID
  static Future<DataSnapshot> getRoomInfo(String roomId) {
    return _roomsRef.child(roomId).get();
  }

  /// Gets a stream of room data changes
  static Stream<DatabaseEvent> getRoomStream(String roomId) {
    return _roomsRef.child(roomId).onValue;
  }

  /// Deletes a room completely
  static Future<void> deleteRoom(String roomId) async {
    final roomRef = _roomsRef.child(roomId);
    await roomRef.onDisconnect().cancel();
    await roomRef.remove();
  }

  // ============================================================================
  // PARTICIPANT MANAGEMENT
  // ============================================================================

  /// Joins an existing room as a participant
  static Future<void> joinRoom(String roomId) async {
    final user = _auth.currentUser!;
    final roomRef = _roomsRef.child(roomId);
    final participantRef = roomRef.child('participants/${user.uid}');

    final userDoc = await _usersCollection.doc(user.uid).get();
    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;
    String displayId = '';

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      userName = userData['displayName'] ?? userName;
      displayId = userData['displayId'] ?? '';
      userPicture = userData['photoUrl'] ?? userData['userPicture'] ?? userPicture;
    }

    final participantSnapshot = await participantRef.get();
    if (!participantSnapshot.exists) {
      await participantRef.set({
        'userId': user.uid,
        'displayId': displayId,
        'userName': userName,
        'userPicture': userPicture,
        'joinedAt': ServerValue.timestamp,
        'isOnline': true,
        'isMuted': true,
        'isCameraOn': false,
        'onCall': false,
      });

      await roomRef.child('participantCount').set(ServerValue.increment(1));
      await _setupPresence(roomId, user.uid, isOnCall: false, isHost: false);
    }
  }

  /// Leaves a room as a participant
  static Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser!;
    final roomRef = _roomsRef.child(roomId);
    final participantRef = roomRef.child('participants/${user.uid}');

    await participantRef.onDisconnect().cancel();
    await roomRef.child('participantCount').onDisconnect().cancel();

    final participantSnapshot = await participantRef.get();
    if (participantSnapshot.exists) {
      final participantData = participantSnapshot.value as Map<dynamic, dynamic>;
      final bool wasOnCall = participantData['onCall'] ?? false;

      await participantRef.remove();
      await roomRef.child('participantCount').set(ServerValue.increment(-1));

      if (wasOnCall) {
        await roomRef.child('onCallCount').set(ServerValue.increment(-1));
      }
    }
  }

  /// Gets a stream of participants in a room
  static Stream<DatabaseEvent> getRoomParticipants(String roomId) {
    return _roomsRef.child('$roomId/participants').orderByChild('joinedAt').onValue;
  }

  /// Sets up presence detection for connected/disconnected users
  static Future<void> _setupPresence(
    String roomId,
    String userId, {
    required bool isOnCall,
    required bool isHost,
  }) async {
    final participantRef = _roomsRef.child('$roomId/participants/$userId');
    final roomRef = _roomsRef.child(roomId);

    _connectedRef.onValue.listen((event) async {
      if (event.snapshot.value == true) {
        if (isHost) {
          await roomRef.child('participantCount').onDisconnect().cancel();
          await roomRef.onDisconnect().remove();
        } else {
          await participantRef.onDisconnect().remove();
          await roomRef.child('participantCount').onDisconnect().set(ServerValue.increment(-1));

          if (isOnCall) {
            await roomRef.child('onCallCount').onDisconnect().set(ServerValue.increment(-1));
          }
        }
        await participantRef.child('isOnline').set(true);
      }
    });
  }

  // ============================================================================
  // PARTICIPANT STATE MANAGEMENT
  // ============================================================================

  /// Toggles mute state for current user
  static Future<void> toggleMuteState(String roomId, bool newMuteState) async {
    final user = _auth.currentUser!;
    await _roomsRef.child('$roomId/participants/${user.uid}').update({'isMuted': newMuteState});
  }

  /// Toggles camera state for current user
  static Future<void> toggleCameraState(String roomId, bool isCameraOn) async {
    final user = _auth.currentUser!;
    await _roomsRef.child('$roomId/participants/${user.uid}').update({'isCameraOn': isCameraOn});
  }

  // ============================================================================
  // JOIN REQUESTS
  // ============================================================================

  /// Sends a request to join a room
  static Future<void> requestToJoin(String roomId) async {
    final user = _auth.currentUser!;
    final roomRef = _roomsRef.child(roomId);

    final userDoc = await _usersCollection.doc(user.uid).get();
    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;
    String displayId = '';

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      userName = userData['displayName'] ?? userName;
      displayId = userData['displayId'] ?? '';
      userPicture = userData['photoUrl'] ?? userData['userPicture'] ?? userPicture;
    }

    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      throw Exception("Room does not exist.");
    }

    await roomRef.child('join_requests/${user.uid}').set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': userName,
      'userPicture': userPicture,
      'requestedAt': ServerValue.timestamp,
    });
  }

  /// Gets a stream of join requests for a room
  static Stream<DatabaseEvent> getJoinRequestsStream(String roomId) {
    return _roomsRef.child('$roomId/join_requests').orderByChild('requestedAt').onValue;
  }

  /// Approves a join request
  static Future<void> approveJoinRequest(String roomId, String requestId, String userId) async {
    final roomRef = _roomsRef.child(roomId);
    final requestRef = roomRef.child('join_requests/$requestId');
    final participantRef = roomRef.child('participants/$userId');

    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) throw Exception("Room does not exist.");

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final currentOnCallCount = roomData['onCallCount'] ?? 0;

    if (currentOnCallCount >= 4) {
      throw Exception("The room is full. Cannot approve more participants.");
    }

    await participantRef.update({'isMuted': false, 'isCameraOn': true, 'onCall': true});
    await roomRef.child('onCallCount').set(ServerValue.increment(1));
    await requestRef.remove();
  }

  /// Rejects a join request
  static Future<void> rejectJoinRequest(String roomId, String requestId) async {
    await _roomsRef.child('$roomId/join_requests/$requestId').remove();
  }

  // ============================================================================
  // USER ROOM QUERIES
  // ============================================================================

  /// Finds the active room where the user is the host
  static Future<String?> getUserActiveRoom(String userId) async {
    try {
      final snapshot = await _roomsRef.orderByChild('hostId').equalTo(userId).limitToFirst(1).get();

      if (snapshot.exists) {
        final rooms = snapshot.value as Map<dynamic, dynamic>;
        return rooms.keys.first;
      }
      return null;
    } catch (e) {
      debugPrint("Error checking user active room: $e");
      return null;
    }
  }

  /// Finds any room where the user is present (as host or participant)
  static Future<String?> getUserCurrentRoom(String userId) async {
    try {
      final hostingRoom = await getUserActiveRoom(userId);
      if (hostingRoom != null) return hostingRoom;

      final snapshot = await _roomsRef.orderByChild('isActive').equalTo(true).get();

      if (snapshot.exists) {
        final rooms = snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rooms.entries) {
          final roomId = entry.key;
          final participantsSnapshot = await _roomsRef.child('$roomId/participants/$userId').get();

          if (participantsSnapshot.exists) {
            return roomId;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error checking user current room: $e");
      return null;
    }
  }
}
