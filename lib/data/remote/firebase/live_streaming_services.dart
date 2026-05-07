import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../../ui/live_streaming/bottomsheets/invite_pk_bottomsheet.dart';

/// Optimized Service class for managing live streaming rooms using flattened Firebase RTDB
class LiveStreamService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final _usersCollection = _firestore.collection('users');

  // ============================================================================
  // FLATTENED DATABASE REFERENCES (COST SAVERS)
  // ============================================================================
  static final DatabaseReference _roomsRef = _database.ref('live_streams');
  static final DatabaseReference _participantsRef = _database.ref('live_participants');
  static final DatabaseReference _eventsRef = _database.ref('live_events');
  static final DatabaseReference _requestsRef = _database.ref('live_requests');
  static final DatabaseReference _globalRandomPKRef = _database.ref('globalRandomLivePKInvites');

  static final Map<String, StreamSubscription> _participantCountListeners = {};
  static final Map<String, Timer?> _heartbeatTimers = {};

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  static Future<String> createRoom() async {
    final user = _auth.currentUser!;

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

    final userDoc = await _usersCollection.doc(user.uid).get();
    if (!userDoc.exists) throw Exception("User profile not found. Cannot create room.");

    final userData = userDoc.data() as Map<String, dynamic>;
    final String hostName = userData['displayName'] ?? 'Anonymous';
    final String? hostPicture = userData['photoUrl'];
    final String displayId = userData['displayId'] ?? '';

    final String hostCountry = userData['country'] ?? 'Unknown';

    // 1. Static Room Data
    await roomRef.set({
      'hostId': user.uid,
      'hostDisplayId': displayId,
      'hostName': hostName,
      'hostPicture': hostPicture,
      'hostCountry': hostCountry,
      'createdAt': ServerValue.timestamp,
      'isActive': true,
      'participantCount': 1,
      'isLocked': false,
      'password': null,
      'notice': '',
      'lastActive': ServerValue.timestamp,
    });

    // 2. Flattened Participant Data
    final participantRef = _participantsRef.child('$roomId/${user.uid}');
    await participantRef.set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': hostName,
      'userPicture': hostPicture,
      'joinedAt': ServerValue.timestamp,
      'isOnline': true,
      'isMuted': false,
      'isCameraOn': true,
      'isOnSeat': true,
    });

    await _setupPresence(roomId, user.uid, isHost: true);
    _setupParticipantCountSync(roomId);

    return roomId;
  }

  static Stream<DatabaseEvent> getAllRooms() => _roomsRef.orderByChild('isActive').equalTo(true).onValue;

  static Future<DataSnapshot> getRoomInfo(String roomId) => _roomsRef.child(roomId).get();

  static Stream<DatabaseEvent> getRoomStream(String roomId) => _roomsRef.child(roomId).onValue;

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

      await _roomsRef.child(roomId).onDisconnect().cancel();
      await _participantsRef.child(roomId).onDisconnect().cancel();
      await _eventsRef.child(roomId).onDisconnect().cancel();
      await _requestsRef.child(roomId).onDisconnect().cancel();

      await _roomsRef.child(roomId).remove();
      await _participantsRef.child(roomId).remove();
      await _eventsRef.child(roomId).remove();
      await _requestsRef.child(roomId).remove();
    } catch (e) {
      debugPrint('Error deleting live stream: $e');
      rethrow;
    }
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
              'roomType': 'video',
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
              'roomType': 'video',
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
      debugPrint('❌ Error saving video live history: $e');
      rethrow;
    }
  }

  static Future<void> setRoomNotice(String roomId, String notice) async {
    try {
      await _roomsRef.child(roomId).update({'notice': notice});
    } catch (e) {
      debugPrint('Error setting room notice: $e');
      throw Exception('Failed to set room notice');
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
        'isMuted': false,
        'isCameraOn': false,
        'isOnSeat': false,
      });

      await _setupPresence(roomId, user.uid, isHost: false);
    }
  }

  static Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    try {
      await participantRef.onDisconnect().cancel();
      await participantRef.remove();
      await _requestsRef.child('$roomId/join_requests/${user.uid}').remove();
    } catch (e) {
      debugPrint('Error leaving room: $e');
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

  static Future<void> pausePresence(String roomId, bool isHost) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (isHost) {
        final participantRef = _participantsRef.child('$roomId/${user.uid}');
        await participantRef.child('isOnline').onDisconnect().cancel();
        _heartbeatTimers[roomId]?.cancel();
        _heartbeatTimers[roomId] = null;
      }
    } catch (e) {
      debugPrint('Error pausing presence: $e');
    }
  }

  static Future<void> resumePresence(String roomId, String userId, {required bool isHost}) async {
    try {
      final roomRef = _roomsRef.child(roomId);
      final participantRef = _participantsRef.child('$roomId/$userId');
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) return;

      if (isHost) {
        await participantRef.child('isOnline').onDisconnect().set(false);
        await roomRef.child('lastActive').set(ServerValue.timestamp);
        _startForegroundHeartbeat(roomId);
        await participantRef.child('isOnline').set(true);
      } else {
        final participantSnapshot = await participantRef.get();
        if (!participantSnapshot.exists) {
          await joinRoom(roomId);
        } else {
          await participantRef.onDisconnect().remove();
          await participantRef.child('isOnline').set(true);
        }
      }
    } catch (e) {
      debugPrint('Error resuming presence: $e');
      rethrow;
    }
  }

  static Future<void> demoteAllParticipantsToViewers(String roomId, String hostId) async {
    final pRef = _participantsRef.child(roomId);
    try {
      final snapshot = await pRef.get();
      if (!snapshot.exists) return;
      final participants = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in participants.entries) {
        if (entry.key != hostId) {
          await pRef.child(entry.key).update({'isMuted': false, 'isCameraOn': false, 'isOnSeat': false});
        }
      }
    } catch (e) {
      debugPrint("Error demoting participants: $e");
    }
  }

  static Future<void> leaveSeat(String roomId) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({
      'isOnSeat': false,
      'isMuted': false,
      'isCameraOn': false,
    });
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
    await _requestsRef.child('$roomId/join_requests/$userId').remove();
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

  static Future<void> toggleCameraState(String roomId, bool isCameraOn) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({'isCameraOn': isCameraOn});
  }

  // ============================================================================
  // JOIN REQUESTS
  // ============================================================================

  static Future<void> requestToJoin(String roomId) async {
    final user = _auth.currentUser!;
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

    await _requestsRef.child('$roomId/join_requests/${user.uid}').set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': userName,
      'userPicture': userPicture,
      'requestedAt': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getJoinRequestsStream(String roomId) {
    return _requestsRef.child('$roomId/join_requests').orderByChild('requestedAt').onValue;
  }

  static Future<void> approveJoinRequest(String roomId, String requestId, String userId) async {
    final requestRef = _requestsRef.child('$roomId/join_requests/$requestId');

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    int seatedCount = 0;
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      seatedCount = participants.values.where((p) => p is Map && p['isOnSeat'] == true).length;
    }

    if (seatedCount >= 5) throw Exception("The call seats are full.");

    final participantRef = _participantsRef.child('$roomId/$userId');
    await participantRef.update({'isOnSeat': true, 'isMuted': false, 'isCameraOn': true});
    await requestRef.remove();
  }

  static Future<void> rejectJoinRequest(String roomId, String requestId) async {
    await _requestsRef.child('$roomId/join_requests/$requestId').remove();
  }

  // ============================================================================
  // FAST EVENTS (EMOJIS & GIFTS)
  // ============================================================================

  static Future<void> sendEmoji(String roomId, String emojiUrl, String emojiName) async {
    final user = _auth.currentUser!;
    final participantSnapshot = await _participantsRef.child('$roomId/${user.uid}').get();

    if (!participantSnapshot.exists) throw Exception("You must join the room first.");

    final userDoc = await _usersCollection.doc(user.uid).get();
    String userName = userDoc.data()?['displayName'] ?? user.displayName ?? 'Anonymous';

    // OVERWRITE instead of push
    await _eventsRef.child('$roomId/latest_emoji').set({
      'senderId': user.uid,
      'senderName': userName,
      'emojiUrl': emojiUrl,
      'emojiName': emojiName,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getEmojiStream(String roomId) => _eventsRef.child('$roomId/latest_emoji').onValue;

  static Future<void> sendGift({
    int? hitCount,
    required String roomId,
    required String giftAnimationUrl,
    required String giftImageUrl,
    required int giftValue,
    String? category,
    String? receiverId,
    String? receiverName,
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
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getGiftStream(String roomId) => _eventsRef.child('$roomId/latest_gift').onValue;

  // ============================================================================
  // USER ROOM QUERIES
  // ============================================================================

  static Future<String?> getUserActiveRoom(String userId) async {
    try {
      final snapshot = await _roomsRef.orderByChild('hostId').equalTo(userId).once();
      if (!snapshot.snapshot.exists) return null;

      for (final child in snapshot.snapshot.children) {
        final roomData = child.value as Map<dynamic, dynamic>;
        if (roomData['isActive'] == true) return child.key;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getUserCurrentRoom(String userId) async {
    try {
      final hostingRoom = await getUserActiveRoom(userId);
      if (hostingRoom != null) return hostingRoom;

      final snapshot = await _roomsRef.orderByChild('isActive').equalTo(true).once();
      if (!snapshot.snapshot.exists) return null;

      for (final child in snapshot.snapshot.children) {
        final roomId = child.key.toString();
        final participantSnapshot = await _participantsRef.child('$roomId/$userId').get();
        if (participantSnapshot.exists) return roomId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // PK BATTLE SYSTEM
  // ============================================================================

  static Future<void> sendPKInvite({
    required String senderRoomId,
    required String receiverUserId,
    required int durationInMinutes,
  }) async {
    final user = _auth.currentUser!;
    final receiverRoomId = await getUserActiveRoom(receiverUserId);

    if (receiverRoomId == null) throw Exception("User is not in a room.");

    final receiverRoomSnapshot = await _roomsRef.child(receiverRoomId).get();
    if (receiverRoomSnapshot.exists) {
      final pkState = (receiverRoomSnapshot.value as Map)['pkState'] as Map<dynamic, dynamic>? ?? {'isPK': false};
      if (pkState['isPK'] == true) throw Exception("User is already in a PK battle.");
    }

    final inviteRef = _requestsRef.child('$receiverRoomId/pk_invites/$senderRoomId');
    await inviteRef.set({
      'senderRoomId': senderRoomId,
      'senderHostId': user.uid,
      'senderHostName': user.displayName ?? 'Anonymous',
      'senderHostPicture': user.photoURL,
      'receiverRoomId': receiverRoomId,
      'receiverHostId': receiverUserId,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'durationInMinutes': durationInMinutes,
    });
  }

  static Stream<List<PKInvite>> getPKInvitesStream(String myRoomId) {
    return _requestsRef.child('$myRoomId/pk_invites').orderByChild('status').equalTo('pending').onValue.map((event) {
      if (!event.snapshot.exists) return <PKInvite>[];
      final invitesMap = event.snapshot.value as Map<dynamic, dynamic>;
      return invitesMap.entries.map((entry) => PKInvite.fromRTDB(entry.key, entry.value)).toList();
    });
  }

  static Stream<List<PKInvite>> getSentPKInvitesStream(String mySenderRoomId) => Stream.value([]);

  static Future<void> acceptPKInvite(String myRoomId, PKInvite invite) async {
    final myRoomRef = _roomsRef.child(myRoomId);
    final senderRoomRef = _roomsRef.child(invite.senderRoomId);
    final myRoomSnapshot = await myRoomRef.get();
    final myRoomData = myRoomSnapshot.value as Map<dynamic, dynamic>;

    final int duration = invite.durationInMinutes;
    final pkEndTime = DateTime.now().add(Duration(minutes: duration)).millisecondsSinceEpoch;

    await myRoomRef.update({
      'pkState': {
        'isPK': true,
        'opponentRoomId': invite.senderRoomId,
        'opponentHostId': invite.senderHostId,
        'opponentHostName': invite.senderHostName,
        'role': 'receiver',
        'durationInMinutes': duration,
        'pkEndTime': pkEndTime,
      },
    });

    await senderRoomRef.update({
      'pkState': {
        'isPK': true,
        'opponentRoomId': myRoomId,
        'opponentHostId': myRoomData['hostId'],
        'opponentHostName': myRoomData['hostName'],
        'role': 'sender',
        'durationInMinutes': duration,
        'pkEndTime': pkEndTime,
      },
    });

    await _requestsRef.child('$myRoomId/pk_invites/${invite.id}').update({'status': 'accepted'});
  }

  static Future<void> rejectPKInvite(String myRoomId, PKInvite invite) async {
    await _requestsRef.child('$myRoomId/pk_invites/${invite.id}').remove();
  }

  static Future<void> endPKBattle(String myRoomId, String opponentRoomId) async {
    await _roomsRef.child(myRoomId).update({
      'pkState': {'isPK': false},
    });
    await _roomsRef.child(opponentRoomId).update({
      'pkState': {'isPK': false},
    });
    await _requestsRef.child('$myRoomId/pk_invites/$opponentRoomId').remove();
    await _requestsRef.child('$opponentRoomId/pk_invites/$myRoomId').remove();
  }

  // ============================================================================
  // RANDOM PK SYSTEM
  // ============================================================================

  static Future<void> sendGlobalRandomPKInvite(String senderRoomId, int durationInMinutes) async {
    final user = _auth.currentUser!;
    final senderRoomSnapshot = await _roomsRef.child(senderRoomId).get();
    if (!senderRoomSnapshot.exists) throw Exception('Your room does not exist.');

    final senderRoomData = senderRoomSnapshot.value as Map<dynamic, dynamic>;
    final pkState = senderRoomData['pkState'] as Map<dynamic, dynamic>? ?? {'isPK': false};
    if (pkState['isPK'] == true) throw Exception('You are already in a PK battle.');

    final inviteRef = _globalRandomPKRef.push();
    await inviteRef.set({
      'inviteId': inviteRef.key!,
      'senderRoomId': senderRoomId,
      'senderHostId': user.uid,
      'senderHostName': senderRoomData['hostName'] ?? (user.displayName ?? 'Anonymous'),
      'senderHostPicture': senderRoomData['hostPicture'] ?? user.photoURL,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'durationInMinutes': durationInMinutes,
      'expiresAt': DateTime.now().add(const Duration(seconds: 7)).millisecondsSinceEpoch,
    });

    Future.delayed(const Duration(seconds: 7), () async {
      try {
        final snapshot = await inviteRef.get();
        if (snapshot.exists && (snapshot.value as Map)['status'] == 'pending') {
          await inviteRef.remove();
        }
      } catch (e) {
        debugPrint('Error auto-deleting random PK invite: $e');
      }
    });
  }

  static Stream<List<PKInvite>> getGlobalRandomPKInvitesStream() {
    return _globalRandomPKRef.onValue.map((event) {
      if (!event.snapshot.exists) return <PKInvite>[];
      final value = event.snapshot.value;
      if (value == null || value is! Map) return <PKInvite>[];

      final invitesMap = Map<dynamic, dynamic>.from(value);
      return invitesMap.entries.where((entry) => entry.value is Map).map((entry) {
        final inviteData = Map<dynamic, dynamic>.from(entry.value as Map);
        return PKInvite(
          id: entry.key.toString(),
          senderRoomId: inviteData['senderRoomId'] ?? '',
          senderHostId: inviteData['senderHostId'] ?? '',
          senderHostName: inviteData['senderHostName'] ?? 'Unknown',
          senderHostPicture: inviteData['senderHostPicture'],
          receiverRoomId: '',
          receiverHostId: '',
          durationInMinutes: inviteData['durationInMinutes'] ?? 5,
          isRandom: true,
        );
      }).toList();
    });
  }

  static Future<void> acceptGlobalRandomPKInvite(String roomId, PKInvite invite) async {
    final user = _auth.currentUser!;
    final senderRoomSnapshot = await _roomsRef.child(invite.senderRoomId).get();

    if (!senderRoomSnapshot.exists) throw Exception('Sender room no longer exists.');
    final senderPkState = (senderRoomSnapshot.value as Map)['pkState'] as Map<dynamic, dynamic>? ?? {'isPK': false};
    if (senderPkState['isPK'] == true) throw Exception('PK already started with someone else.');

    final myRoomSnapshot = await _roomsRef.child(roomId).get();
    if (myRoomSnapshot.exists) {
      final myPkState = (myRoomSnapshot.value as Map)['pkState'] as Map<dynamic, dynamic>? ?? {'isPK': false};
      if (myPkState['isPK'] == true) throw Exception('You are already in a PK battle.');
    }

    await _globalRandomPKRef.child(invite.id).remove();

    final pkEndTime = DateTime.now().add(Duration(minutes: invite.durationInMinutes));
    final receiverDoc = await _usersCollection.doc(user.uid).get();
    final receiverName = receiverDoc.data()?['displayName'] ?? 'Unknown';
    final receiverPicture = receiverDoc.data()?['profilePicture'];

    await _roomsRef.child(roomId).child('pkState').set({
      'isPK': true,
      'opponentRoomId': invite.senderRoomId,
      'opponentHostId': invite.senderHostId,
      'opponentHostName': invite.senderHostName,
      'opponentHostPicture': invite.senderHostPicture,
      'pkEndTime': pkEndTime.millisecondsSinceEpoch,
      'role': 'receiver',
    });

    await _roomsRef.child(invite.senderRoomId).child('pkState').set({
      'isPK': true,
      'opponentRoomId': roomId,
      'opponentHostId': user.uid,
      'opponentHostName': receiverName,
      'opponentHostPicture': receiverPicture,
      'pkEndTime': pkEndTime.millisecondsSinceEpoch,
      'role': 'sender',
    });
  }
}
