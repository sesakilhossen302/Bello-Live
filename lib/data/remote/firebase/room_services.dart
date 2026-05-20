import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RoomService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final _usersCollection = _firestore.collection('users');

  // ============================================================================
  // FLATTENED DATABASE REFERENCES (THE COST SAVER)
  // ============================================================================
  static final DatabaseReference _roomsRef = _database.ref('rooms'); // Only slow/static data
  static final DatabaseReference _participantsRef = _database.ref('room_participants'); // Fast delta updates
  static final DatabaseReference _eventsRef = _database.ref('room_events'); // Overwrites for emojis/gifts
  static final DatabaseReference _requestsRef = _database.ref('room_requests'); // Host-only private data

  // Track active listeners and timers to prevent memory leaks and duplicates
  static final Map<String, StreamSubscription> _participantCountListeners = {};
  static final Map<String, Timer?> _heartbeatTimers = {};

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  static Future<String> createRoom({String? password}) async {
    final user = _auth.currentUser!;
    final userRef = _usersCollection.doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw Exception('User profile not found. Cannot create room.');
    }

    // Clean up existing room if host already has one
    final existingRoomSnapshot = await _roomsRef.orderByChild('hostId').equalTo(user.uid).once();
    if (existingRoomSnapshot.snapshot.exists) {
      for (final child in existingRoomSnapshot.snapshot.children) {
        final oldRoomId = child.key;
        if (oldRoomId != null) {
          await child.ref.remove();
          await _participantsRef.child(oldRoomId).remove();
          await _eventsRef.child(oldRoomId).remove();
          await _requestsRef.child(oldRoomId).remove();
        }
      }
    }

    final roomRef = _roomsRef.push();
    final roomId = roomRef.key!;

    final userData = userDoc.data() as Map<String, dynamic>;
    final String hostName = userData['displayName'] ?? 'Anonymous';
    final String displayId = userData['displayId'] ?? '';
    final String? hostPicture = userData['photoUrl'];
    final String hostCountry = userData['country'] ?? 'Unknown';
    final bool isLocked = password != null && password.isNotEmpty;

    // 1. Create STATIC room data
    await roomRef.set({
      'hostId': user.uid,
      'hostDisplayId': displayId,
      'hostName': hostName,
      'hostPicture': hostPicture,
      'hostCountry': hostCountry,
      'createdAt': ServerValue.timestamp,
      'isActive': true,
      'participantCount': 1,
      'isMoveAllowed': true,
      'isSeatApprovalRequired': false,
      'isLocked': isLocked,
      'password': isLocked ? password : null,
      'lastActive': ServerValue.timestamp,
    });

    // 2. Create FAST participant data (Flattened)
    final participantRef = _participantsRef.child('$roomId/${user.uid}');
    await participantRef.set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': hostName,
      'userPicture': hostPicture,
      'isCoHost': false,
      'seatNo': 0,
      'joinedAt': ServerValue.timestamp,
      'isOnline': true,
      'isMuted': false,
    });

    await _setupPresence(roomId, user.uid, isHost: true);
    _setupParticipantCountSync(roomId);
    await _usersCollection.doc(user.uid).update({'currentRoomId': roomId});

    return roomId;
  }

  static Stream<DatabaseEvent> getAllRooms() {
    return _roomsRef.orderByChild('isActive').equalTo(true).onValue;
  }

  static Future<DataSnapshot> getRoomInfo(String roomId) {
    return _roomsRef.child(roomId).get();
  }

  static Stream<DatabaseEvent> getRoomStream(String roomId) {
    return _roomsRef.child(roomId).onValue;
  }

  static Future<void> saveLiveSessionHistory({
    required String roomId,
    required String hostId,
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    try {
      final duration = endTimestamp - startTimestamp;
      final durationMinutes = (duration / 1000 / 60).round();

      final sessionDate = DateTime.fromMillisecondsSinceEpoch(startTimestamp);
      final dateKey =
          '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';

      final historyRef = _usersCollection.doc(hostId).collection('liveHistory').doc(dateKey);
      final docSnapshot = await historyRef.get();

      if (docSnapshot.exists) {
        await historyRef.update({
          'totalDurationMinutes': FieldValue.increment(durationMinutes),
          'sessions': FieldValue.arrayUnion([
            {
              'roomId': roomId,
              'roomType': 'audio',
              'startTime': Timestamp.fromMillisecondsSinceEpoch(startTimestamp),
              'endTime': Timestamp.fromMillisecondsSinceEpoch(endTimestamp),
              'durationMinutes': durationMinutes,
            },
          ]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await historyRef.set({
          'date': dateKey,
          'totalDurationMinutes': durationMinutes,
          'sessions': [
            {
              'roomId': roomId,
              'roomType': 'audio',
              'startTime': Timestamp.fromMillisecondsSinceEpoch(startTimestamp),
              'endTime': Timestamp.fromMillisecondsSinceEpoch(endTimestamp),
              'durationMinutes': durationMinutes,
            },
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving live history: $e');
      rethrow;
    }
  }

  static Future<void> deleteRoom(String roomId) async {
    try {
      final roomSnapshot = await _roomsRef.child(roomId).get();
      if (roomSnapshot.exists) {
        final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
        final startTime = roomData['createdAt'] as int?;
        final hostId = roomData['hostId'] as String?;

        if (startTime != null && hostId != null) {
          final endTime = DateTime.now().millisecondsSinceEpoch;
          await saveLiveSessionHistory(
            roomId: roomId,
            hostId: hostId,
            startTimestamp: startTime,
            endTimestamp: endTime,
          );
        }
      }

      _heartbeatTimers[roomId]?.cancel();
      _heartbeatTimers.remove(roomId);

      _participantCountListeners[roomId]?.cancel();
      _participantCountListeners.remove(roomId);

      // Cancel onDisconnects
      await _roomsRef.child(roomId).onDisconnect().cancel();
      await _participantsRef.child(roomId).onDisconnect().cancel();
      await _eventsRef.child(roomId).onDisconnect().cancel();
      await _requestsRef.child(roomId).onDisconnect().cancel();

      // Delete all flattened data
      await _roomsRef.child(roomId).remove();
      await _participantsRef.child(roomId).remove();
      await _eventsRef.child(roomId).remove();
      await _requestsRef.child(roomId).remove();
    } catch (e) {
      debugPrint('Error deleting room: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PARTICIPANT MANAGEMENT
  // ============================================================================

  static Future<void> joinRoom(String roomId) async {
    final user = _auth.currentUser!;

    // Check if blocked
    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (roomSnapshot.exists) {
      final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
      final blockedUsers = roomData['blockedUsers'] as Map<dynamic, dynamic>?;
      if (blockedUsers != null && blockedUsers.containsKey(user.uid)) {
        final expiry = blockedUsers[user.uid] as int;
        if (expiry == -1 || expiry > DateTime.now().millisecondsSinceEpoch) {
          throw Exception('You are blocked from this room.');
        }
      }
    }

    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    final userProfileDoc = await _firestore.collection('users').doc(user.uid).get();

    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;
    String displayId = '';

    if (userProfileDoc.exists) {
      final data = userProfileDoc.data() as Map<String, dynamic>;
      userName = data['displayName'] ?? userName;
      displayId = data['displayId'] ?? '';
      userPicture = data['photoUrl'] ?? data['profilePicture'] ?? userPicture;
    }

    await participantRef.set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': userName,
      'userPicture': userPicture,
      'isCoHost': false,
      'seatNo': -1,
      'joinedAt': ServerValue.timestamp,
      'isOnline': true,
      'isMuted': false,
    });

    await _setupPresence(roomId, user.uid, isHost: false);
    await _usersCollection.doc(user.uid).update({'currentRoomId': roomId});
  }

  static Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    try {
      await participantRef.onDisconnect().cancel();
      await participantRef.remove();
      await _requestsRef.child('$roomId/speaker_requests/${user.uid}').remove();
      await _requestsRef.child('$roomId/cohost_requests/${user.uid}').remove();
      await _usersCollection.doc(user.uid).update({'currentRoomId': null});
    } catch (e) {
      debugPrint('Error leaving room: $e');
      rethrow;
    }
  }

  static Stream<DatabaseEvent> getRoomParticipants(String roomId) {
    return _participantsRef.child(roomId).orderByChild('joinedAt').onValue;
  }

  static void _setupParticipantCountSync(String roomId) {
    _participantCountListeners[roomId]?.cancel();

    _participantCountListeners[roomId] = _participantsRef.child(roomId).onValue.listen((event) async {
      if (!event.snapshot.exists) {
        await _roomsRef.child('$roomId/participantCount').set(0);
        return;
      }

      final participants = event.snapshot.value;
      if (participants is Map) {
        final actualCount = participants.length;
        final countSnapshot = await _roomsRef.child('$roomId/participantCount').get();
        final currentCount = (countSnapshot.value as int?) ?? 0;

        if (currentCount != actualCount) {
          await _roomsRef.child('$roomId/participantCount').set(actualCount);
        }
      }
    });
  }

  static Future<void> _setupPresence(String roomId, String userId, {required bool isHost}) async {
    final roomRef = _roomsRef.child(roomId);
    final participantRef = _participantsRef.child('$roomId/$userId');

    try {
      if (isHost) {
        await participantRef.child('isOnline').onDisconnect().set(false);
        _participantCountListeners[roomId]?.cancel();
        _participantCountListeners.remove(roomId);
        await roomRef.child('lastActive').set(ServerValue.timestamp);
        _startForegroundHeartbeat(roomId);
      } else {
        await participantRef.onDisconnect().remove();
      }
      await participantRef.child('isOnline').set(true);
    } catch (e) {
      debugPrint('Error setting up presence: $e');
      rethrow;
    }
  }

  static void _startForegroundHeartbeat(String roomId) {
    _heartbeatTimers[roomId]?.cancel();
    _heartbeatTimers[roomId] = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        await _roomsRef.child('$roomId/lastActive').set(ServerValue.timestamp);
      } catch (e) {
        timer.cancel();
      }
    });
  }

  // ============================================================================
  // SEAT MANAGEMENT
  // ============================================================================

  static Future<void> leaveSeat(String roomId) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({'seatNo': -1, 'isMuted': false});
  }

  static Future<void> takeSeat(String roomId, int newSeatNo) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (!roomSnapshot.exists) throw Exception('Room not found.');

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final lockedSeatsMap = roomData['lockedSeats'];
    bool isLocked = false;
    if (lockedSeatsMap is Map) {
      isLocked = lockedSeatsMap['seat_$newSeatNo'] == true ||
          lockedSeatsMap[newSeatNo.toString()] == true;
    } else if (lockedSeatsMap is List) {
      if (newSeatNo < lockedSeatsMap.length) {
        isLocked = lockedSeatsMap[newSeatNo] == true;
      }
    }
    if (isLocked) {
      throw Exception('This seat is locked by the host.');
    }

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map && participant['seatNo'] == newSeatNo) {
          throw Exception('Seat is already occupied.');
        }
      }
    }

    await participantRef.update({'seatNo': newSeatNo, 'isMuted': false});
  }

  static Future<void> moveSeat(String roomId, int newSeatNo) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (roomSnapshot.exists) {
      final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
      if (!(roomData['isMoveAllowed'] ?? true)) {
        throw Exception('Host has disabled moving seats.');
      }
      final lockedSeatsMap = roomData['lockedSeats'];
      bool isLocked = false;
      if (lockedSeatsMap is Map) {
        isLocked = lockedSeatsMap['seat_$newSeatNo'] == true ||
            lockedSeatsMap[newSeatNo.toString()] == true;
      } else if (lockedSeatsMap is List) {
        if (newSeatNo < lockedSeatsMap.length) {
          isLocked = lockedSeatsMap[newSeatNo] == true;
        }
      }
      if (isLocked) {
        throw Exception('This seat is locked by the host.');
      }
    }

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map && participant['seatNo'] == newSeatNo) {
          throw Exception('Seat is already occupied.');
        }
      }
    }

    await participantRef.update({'seatNo': newSeatNo, 'isCoHost': false});
  }

  static Future<void> toggleMuteState(String roomId, bool newMuteState) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({'isMuted': newMuteState});
  }

  static Future<void> muteParticipant(String roomId, String userId, bool isMuted) async {
    await _participantsRef.child('$roomId/$userId').update({'isMuted': isMuted});
  }

  static Future<void> lockParticipant(String roomId, String userId, bool isLocked) async {
    await _participantsRef.child('$roomId/$userId').update({'isLocked': isLocked});
  }

  static Future<void> kickParticipant(String roomId, String userId) async {
    await _participantsRef.child('$roomId/$userId').remove();
    await _requestsRef.child('$roomId/speaker_requests/$userId').remove();
    await _requestsRef.child('$roomId/cohost_requests/$userId').remove();
  }

  static Future<void> blockParticipant(String roomId, String userId, {Duration? duration}) async {
    await kickParticipant(roomId, userId);
    final expiry = duration != null
        ? DateTime.now().add(duration).millisecondsSinceEpoch
        : -1; // -1 for permanent
    await _roomsRef.child('$roomId/blockedUsers/$userId').set(expiry);
  }

  static Future<void> unblockUser(String roomId, String userId) async {
    await _roomsRef.child('$roomId/blockedUsers/$userId').remove();
  }

  static Stream<DatabaseEvent> getBlockedUsersStream(String roomId) {
    return _roomsRef.child('$roomId/blockedUsers').onValue;
  }

  // ============================================================================
  // CO-HOST MANAGEMENT
  // ============================================================================

  static Future<void> stepDownFromCoHost(String roomId) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({'isCoHost': false, 'isMuted': false});
  }

  static Future<void> requestToBeCoHost(String roomId) async {
    final user = _auth.currentUser!;
    final userProfileDoc = await _firestore.collection('users').doc(user.uid).get();

    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;

    if (userProfileDoc.exists) {
      final data = userProfileDoc.data() as Map<String, dynamic>;
      userName = data['displayName'] ?? userName;
      userPicture = data['photoUrl'] ?? data['profilePicture'] ?? userPicture;
    }

    await _requestsRef.child('$roomId/cohost_requests/${user.uid}').set({
      'userId': user.uid,
      'userName': userName,
      'userPicture': userPicture,
      'requestedAt': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getCoHostRequestsStream(String roomId) {
    return _requestsRef.child('$roomId/cohost_requests').orderByChild('requestedAt').onValue;
  }

  static Future<void> approveCoHostRequest(String roomId, String requestId, String userId) async {
    final requestRef = _requestsRef.child('$roomId/cohost_requests/$requestId');
    final participantRef = _participantsRef.child('$roomId/$userId');

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (!roomSnapshot.exists) throw Exception('Room not found.');

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final hostId = roomData['hostId'];

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var entry in participants.entries) {
        if (entry.key != hostId && entry.value is Map) {
          final participant = entry.value as Map<dynamic, dynamic>;
          if (participant['isCoHost'] == true) {
            await requestRef.remove();
            throw Exception('Co-host seat is already occupied.');
          }
        }
      }
    }

    await participantRef.update({'isCoHost': true, 'seatNo': -1, 'isMuted': false});
    await requestRef.remove();
  }

  static Future<void> promoteToCoHost(String roomId, String userId) async {
    final participantRef = _participantsRef.child('$roomId/$userId');

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (!roomSnapshot.exists) throw Exception('Room not found.');

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final hostId = roomData['hostId'];

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var entry in participants.entries) {
        if (entry.key != hostId && entry.value is Map) {
          final participant = entry.value as Map<dynamic, dynamic>;
          if (participant['isCoHost'] == true) {
            throw Exception('Co-host seat is already occupied.');
          }
        }
      }
    }

    await participantRef.update({'isCoHost': true, 'seatNo': -1, 'isMuted': false});
    // Also remove any existing requests from this user if any
    await _requestsRef.child('$roomId/cohost_requests/$userId').remove();
    await _requestsRef.child('$roomId/speaker_requests/$userId').remove();
  }

  static Future<void> removeCoHost(String roomId, String userId) async {
    final participantRef = _participantsRef.child('$roomId/$userId');

    // Find first available seat (1-8)
    final participantsSnapshot = await _participantsRef.child(roomId).get();
    final occupiedSeats = <int>{};

    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map) {
          final seatNo = participant['seatNo'] as int?;
          if (seatNo != null && seatNo > 0) {
            occupiedSeats.add(seatNo);
          }
        }
      }
    }

    int targetSeatNo = -1; // Default to listener if no seats available
    for (int i = 1; i <= 8; i++) {
      if (!occupiedSeats.contains(i)) {
        targetSeatNo = i;
        break;
      }
    }

    await participantRef.update({
      'isCoHost': false,
      'seatNo': targetSeatNo,
      'isMuted': false, 
                                     // Usually speakers are unmuted by default in this app.
    });
  }

  static Future<void> rejectCoHostRequest(String roomId, String requestId) async {
    await _requestsRef.child('$roomId/cohost_requests/$requestId').remove();
  }

  // ============================================================================
  // SPEAKER REQUESTS
  // ============================================================================

  static Future<void> requestToBeSpeaker(String roomId) async {
    final user = _auth.currentUser!;
    final userProfileDoc = await _firestore.collection('users').doc(user.uid).get();

    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;

    if (userProfileDoc.exists) {
      final data = userProfileDoc.data() as Map<String, dynamic>;
      userName = data['displayName'] ?? userName;
      userPicture = data['photoUrl'] ?? data['profilePicture'] ?? userPicture;
    }

    await _requestsRef.child('$roomId/speaker_requests/${user.uid}').set({
      'userId': user.uid,
      'userName': userName,
      'userPicture': userPicture,
      'requestedAt': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getSpeakerRequestsStream(String roomId) {
    return _requestsRef.child('$roomId/speaker_requests').orderByChild('requestedAt').onValue;
  }

  static Future<void> approveSpeakerRequest(String roomId, String requestId, String userId) async {
    final requestRef = _requestsRef.child('$roomId/speaker_requests/$requestId');
    final participantRef = _participantsRef.child('$roomId/$userId');

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    final occupiedSeats = <int>{};

    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map) {
          final seatNo = participant['seatNo'] as int?;
          if (seatNo != null && seatNo > 0) {
            occupiedSeats.add(seatNo);
          }
        }
      }
    }

    final roomSnapshot = await _roomsRef.child(roomId).get();
    final lockedSeats = <int>{};
    if (roomSnapshot.exists) {
      final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
      final lockedData = roomData['lockedSeats'];
      if (lockedData is Map) {
        for (var key in lockedData.keys) {
          final sKey = key.toString().replaceFirst('seat_', '');
          final seatNo = int.tryParse(sKey);
          if (seatNo != null && lockedData[key] == true) {
            lockedSeats.add(seatNo);
          }
        }
      } else if (lockedData is List) {
        for (int i = 0; i < lockedData.length; i++) {
          if (lockedData[i] == true) {
            lockedSeats.add(i);
          }
        }
      }
    }

    int? nextAvailableSeat;
    for (int i = 1; i <= 8; i++) {
      if (!occupiedSeats.contains(i) && !lockedSeats.contains(i)) {
        nextAvailableSeat = i;
        break;
      }
    }

    if (nextAvailableSeat == null) {
      await requestRef.remove();
      throw Exception('All seats are full or locked.');
    }

    await participantRef.update({'seatNo': nextAvailableSeat, 'isMuted': false});
    await requestRef.remove();
  }

  static Future<void> rejectSpeakerRequest(String roomId, String requestId) async {
    await _requestsRef.child('$roomId/speaker_requests/$requestId').remove();
  }

  // ============================================================================
  // ROOM SETTINGS
  // ============================================================================

  static Future<void> setRoomNotice(String roomId, String notice) async {
    await _roomsRef.child(roomId).update({'notice': notice});
  }

  static Future<void> updateRoomBackground(String roomId, String backgroundUrl) async {
    await _roomsRef.child(roomId).update({
      'backgroundUrl': backgroundUrl,
      'backgroundUpdatedAt': ServerValue.timestamp,
    });
  }

  static Future<void> toggleMoveAllowed(String roomId, bool isAllowed) async {
    await _roomsRef.child(roomId).update({'isMoveAllowed': isAllowed});
  }

  static Future<void> toggleSeatApprovalRequired(String roomId, bool isRequired) async {
    await _roomsRef.child(roomId).update({'isSeatApprovalRequired': isRequired});
  }

  static Future<void> setOrChangeRoomPassword(String roomId, String password) async {
    await _roomsRef.child(roomId).update({'isLocked': true, 'password': password});
  }

  static Future<void> removeRoomPassword(String roomId) async {
    await _roomsRef.child(roomId).update({'isLocked': false, 'password': null});
  }

  static Future<void> lockSeat(String roomId, int seatNo) async {
    await _roomsRef.child('$roomId/lockedSeats/seat_$seatNo').set(true);
  }

  static Future<void> unlockSeat(String roomId, int seatNo) async {
    await _roomsRef.child('$roomId/lockedSeats/seat_$seatNo').remove();
  }

  // ============================================================================
  // FAST EVENTS (EMOJIS & GIFTS) - LATEST OVERWRITE ONLY
  // ============================================================================

  static Future<void> sendEmoji(String roomId, String emojiUrl, String emojiName) async {
    final user = _auth.currentUser!;
    final participantSnapshot = await _participantsRef.child('$roomId/${user.uid}').get();

    if (!participantSnapshot.exists) throw Exception('You must join the room first.');

    final participantData = participantSnapshot.value as Map<dynamic, dynamic>;
    final int seatNo = participantData['seatNo'] ?? -1;
    final bool isCoHost = participantData['isCoHost'] ?? false;

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (!roomSnapshot.exists) throw Exception('Room not found.');

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final String hostId = roomData['hostId'] ?? '';
    final bool isHost = user.uid == hostId;

    if (!isHost && !isCoHost && seatNo <= 0) {
      throw Exception('Only host, co-host, and seated participants can send emojis.');
    }

    String userName = participantData['userName'] ?? 'User';

    // OVERWRITE instead of push
    await _eventsRef.child('$roomId/latest_emoji').set({
      'senderId': user.uid,
      'senderName': userName,
      'emojiUrl': emojiUrl,
      'emojiName': emojiName,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getEmojiStream(String roomId) {
    return _eventsRef.child('$roomId/latest_emoji').onValue; // Changed from onChildAdded
  }

  static Future<void> sendGiftNotification({
    required String roomId,
    required String senderName,
    required String recipientName,
    required String giftImageUrl,
    required int giftValue,
  }) async {
    // OVERWRITE instead of push
    await _eventsRef.child('$roomId/latest_gift_notification').set({
      'senderName': senderName,
      'recipientName': recipientName,
      'giftImageUrl': giftImageUrl,
      'giftValue': giftValue,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getGiftNotificationsStream(String roomId) {
    return _eventsRef.child('$roomId/latest_gift_notification').onValue; // Changed from onChildAdded
  }

  static Future<void> sendGift({
    int? hitCount,
    required String roomId,
    required String giftAnimationUrl,
    required String giftImageUrl,
    required int giftValue,
    String? category,
    String? receiverId,
    String? receiverName,
    int? duration,
    int? person,
  }) async {
    final user = _auth.currentUser!;
    final participantSnapshot = await _participantsRef.child('$roomId/${user.uid}').get();

    if (!participantSnapshot.exists) throw Exception('You must join the room first.');

    final participantData = participantSnapshot.value as Map<dynamic, dynamic>;
    String userName = participantData['userName'] ?? 'User';
    String? userPicture = participantData['userPicture'];

    // OVERWRITE instead of push
    await _eventsRef.child('$roomId/latest_gift').set({
      'senderId': user.uid,
      'senderName': userName,
      'senderPicture': userPicture,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'giftAnimationUrl': giftAnimationUrl,
      'giftImageUrl': giftImageUrl,
      'giftValue': giftValue,
      'category': category ?? 'Normal',
      'hitCount': hitCount,
      'duration': duration,
      'person': person,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getGiftStream(String roomId) {
    return _eventsRef.child('$roomId/latest_gift').onValue; // Changed from onChildAdded
  }
}
