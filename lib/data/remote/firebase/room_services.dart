import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'profile_services.dart';
import 'global_gift_banner_service.dart';

class RoomService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final _usersCollection = _firestore.collection('users');

  // ============================================================================
  // FLATTENED DATABASE REFERENCES (THE COST SAVER)
  // ============================================================================
  static final DatabaseReference _roomsRef = _database.ref(
    'rooms',
  ); // Only slow/static data
  static final DatabaseReference _participantsRef = _database.ref(
    'room_participants',
  ); // Fast delta updates
  static final DatabaseReference _eventsRef = _database.ref(
    'room_events',
  ); // Overwrites for emojis/gifts
  static final DatabaseReference _requestsRef = _database.ref(
    'room_requests',
  ); // Host-only private data

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

    Map<String, dynamic> userData;
    if (!userDoc.exists || userDoc.data() == null) {
      userData = {
        'uid': user.uid,
        'displayName': user.displayName?.isNotEmpty == true ? user.displayName : 'User_${user.uid.substring(0, 6)}',
        'photoUrl': user.photoURL,
        'displayId': user.uid.substring(0, 6),
        'country': 'Unknown',
        'gender': 'Not specified',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await userRef.set(userData, SetOptions(merge: true));
    } else {
      userData = userDoc.data() as Map<String, dynamic>;
    }

    // Clean up existing room if host already has one
    final existingRoomSnapshot = await _roomsRef
        .orderByChild('hostId')
        .equalTo(user.uid)
        .once();
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
    final String hostName = userData['displayName'] ?? 'Anonymous';
    final String displayId = userData['displayId'] ?? '';
    final String? hostPicture = userData['photoUrl'];
    final String hostCountry = userData['country'] ?? 'Unknown';
    final bool isLocked = password != null && password.isNotEmpty;

    // Check if host has Royal, King, Queen, Crown package and active Room Screen / Skin
    int packagePriority = 0;
    String? packageBadgeUrl;
    String? roomBackgroundUrl;

    if (userData.containsKey('activeAddOns')) {
      final addOns = userData['activeAddOns'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();
      for (var entry in addOns.entries) {
        final key = entry.key.toLowerCase().trim();
        final itemData = entry.value as Map<String, dynamic>?;
        if (itemData != null) {
          final expiry = itemData['expiresAt'] as Timestamp?;
          final isNotExpired = expiry == null || expiry.toDate().isAfter(now);
          if (isNotExpired) {
            final itemName = (itemData['name'] ?? itemData['title'] ?? '').toString().toLowerCase();
            final itemUrl = (itemData['imageUrl'] ?? itemData['imageURL'] ?? '').toString().toLowerCase();
            final fullStr = '$key $itemName $itemUrl';

            // Package Priority check
            if (fullStr.contains('package') ||
                fullStr.contains('royal') ||
                fullStr.contains('king') ||
                fullStr.contains('queen') ||
                fullStr.contains('crown')) {
              int p = 1;
              if (fullStr.contains('royal')) {
                p = 4;
              } else if (fullStr.contains('king')) {
                p = 3;
              } else if (fullStr.contains('queen')) {
                p = 2;
              } else if (fullStr.contains('crown')) {
                p = 1;
              }

              final String? url = (itemData['imageUrl'] ?? itemData['imageURL'])?.toString();
              if (p > packagePriority) {
                packagePriority = p;
                packageBadgeUrl = (url != null && url.isNotEmpty) ? url : packageBadgeUrl;
              } else {
                packageBadgeUrl ??= url;
              }
            }

            // Room Screen / Skin check
            if (key.contains('screen') || key.contains('skin')) {
              final url = itemData['imageUrl'] as String?;
              if (url != null && url.isNotEmpty) {
                roomBackgroundUrl = url;
              }
            }
          }
        }
      }
    }

    if (roomBackgroundUrl == null || roomBackgroundUrl.isEmpty) {
      final prefSkin = userData['preferredRoomSkin'] as String?;
      if (prefSkin != null && prefSkin.isNotEmpty) {
        roomBackgroundUrl = prefSkin;
      }
    }

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
      'hasPackage': packagePriority > 0,
      'packagePriority': packagePriority,
      'packageBadgeUrl': packageBadgeUrl,
      'backgroundUrl': roomBackgroundUrl,
      'backgroundUpdatedAt': ServerValue.timestamp,
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
      'isAdmin': true,
    });

    await _setupPresence(roomId, user.uid, isHost: true);
    
    _setupParticipantCountSync(roomId);
    await _usersCollection.doc(user.uid).update({'currentRoomId': roomId});

    // Send push notification to all followers subscribed to host_$userId topic
    NotificationService.sendTopicNotification(
      topic: 'host_${user.uid}',
      title: 'Pigo Live',
      body: '$hostName is live now! Join the room.',
      data: {
        'roomId': roomId,
        'hostId': user.uid,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );

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
      final durationMs = endTimestamp - startTimestamp;
      final durationSeconds = (durationMs / 1000).round();
      final durationMinutes = (durationMs / 1000 / 60).round();
      final hours = durationSeconds ~/ 3600;
      final minutes = (durationSeconds % 3600) ~/ 60;
      final seconds = durationSeconds % 60;
      final durationFormatted = hours > 0
          ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
          : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      final sessionDate = DateTime.fromMillisecondsSinceEpoch(startTimestamp);
      final dateKey =
          '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';

      final historyRef = _usersCollection
          .doc(hostId)
          .collection('liveHistory')
          .doc(dateKey);
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
              'durationSeconds': durationSeconds,
              'durationFormatted': durationFormatted,
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
              'durationSeconds': durationSeconds,
              'durationFormatted': durationFormatted,
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
    String hostId = '';
    if (roomSnapshot.exists) {
      final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
      hostId = roomData['hostId'] ?? '';
      final blockedUsers = roomData['blockedUsers'] as Map<dynamic, dynamic>?;
      if (blockedUsers != null && blockedUsers.containsKey(user.uid)) {
        final expiry = blockedUsers[user.uid] as int;
        if (expiry == -1 || expiry > DateTime.now().millisecondsSinceEpoch) {
          throw Exception('You are blocked from this room.');
        }
      }
    }

    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    final userProfileDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;
    String displayId = '';
    String? idEntryUrl;

    if (userProfileDoc.exists) {
      final data = userProfileDoc.data() as Map<String, dynamic>;
      final bool isModerator = ProfileService.checkIsModerator(data);
      if (isModerator) {
        // Moderator Stealth / Ghost Mode:
        // Do NOT register as participant in RTDB!
        await participantRef.remove();
        await _usersCollection.doc(user.uid).update({'currentRoomId': roomId});
        return;
      }
      userName = data['displayName'] ?? userName;
      displayId = data['displayId'] ?? '';
      userPicture = data['photoUrl'] ?? data['profilePicture'] ?? userPicture;
      
      final addOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();
      
      Map<String, dynamic>? idEntryData;
      for (var entry in addOns.entries) {
        if (entry.key.toLowerCase().replaceAll(' ', '') == 'identry') {
          idEntryData = entry.value as Map<String, dynamic>?;
          break;
        }
      }
      
      if (idEntryData != null) {
        final expiry = idEntryData['expiresAt'] as Timestamp?;
        if (expiry == null || expiry.toDate().isAfter(now)) {
          idEntryUrl = idEntryData['imageUrl'] as String?;
        }
      }
    }

    // Check if user has an active co-host rental for this host
    bool isCoHost = false;
    int? coHostUntilMs;
    if (hostId.isNotEmpty && user.uid != hostId) {
      final rentalRef = _firestore.collection('cohost_rentals').doc('${hostId}_${user.uid}');
      final rentalDoc = await rentalRef.get();
      if (rentalDoc.exists) {
        final data = rentalDoc.data() as Map<String, dynamic>;
        final String status = data['status'] ?? 'expired';
        final int totalDurationMs = data['totalDurationMs'] ?? 0;
        int elapsedTimeMs = data['elapsedTimeMs'] ?? 0;
        int? lastJoinedAt = data['lastJoinedAt'] as int?;

        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Reconcile if previous session didn't clean up (crashed / network lost)
        if (lastJoinedAt != null && status == 'active') {
          final diff = nowMs - lastJoinedAt;
          if (diff > 0) {
            elapsedTimeMs += diff;
          }
        }

        if (status == 'active' && elapsedTimeMs < totalDurationMs) {
          isCoHost = true;
          coHostUntilMs = nowMs + (totalDurationMs - elapsedTimeMs);
          await rentalRef.update({
            'elapsedTimeMs': elapsedTimeMs,
            'lastJoinedAt': nowMs,
            'status': 'active',
          });
        } else {
          await rentalRef.update({
            'status': 'expired',
            'lastJoinedAt': null,
          });
        }
      }
    }

    final participantSnapshot = await participantRef.get();
    if (!participantSnapshot.exists) {
      await participantRef.set({
        'userId': user.uid,
        'displayId': displayId,
        'userName': userName,
        'userPicture': userPicture,
        'isCoHost': isCoHost,
        'seatNo': -1,
        'joinedAt': ServerValue.timestamp,
        'isOnline': true,
        'isMuted': isCoHost ? false : true,
        'isApprovedSpeaker': isCoHost,
        'isModerator': false,
        'isAdmin': false,
        if (coHostUntilMs != null) 'coHostUntil': coHostUntilMs,
        if (idEntryUrl != null) 'idEntryUrl': idEntryUrl,
      });
    } else {
      await participantRef.update({
        'isOnline': true,
        'userName': userName,
        'userPicture': userPicture,
        if (idEntryUrl != null) 'idEntryUrl': idEntryUrl,
      });
    }

    await _setupPresence(roomId, user.uid, isHost: false);
    await _usersCollection.doc(user.uid).update({'currentRoomId': roomId});
  }

  static Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    try {
      final roomSnap = await _roomsRef.child(roomId).get();
      if (roomSnap.exists) {
        final roomData = roomSnap.value as Map<dynamic, dynamic>;
        final String hostId = roomData['hostId'] ?? '';
        
        if (hostId == user.uid) {
          // If the host is leaving, delete the entire room
          await deleteRoom(roomId);
          return;
        }
      }

      // Check if user was a cohost
      final participantSnap = await participantRef.get();
      if (participantSnap.exists) {
        final data = participantSnap.value as Map<dynamic, dynamic>;
        final bool isCoHost = data['isCoHost'] == true;
        if (isCoHost) {
          if (roomSnap.exists) {
            final roomData = roomSnap.value as Map<dynamic, dynamic>;
            final String hostId = roomData['hostId'] ?? '';
            if (hostId.isNotEmpty) {
              final rentalRef = _firestore.collection('cohost_rentals').doc('${hostId}_${user.uid}');
              final rentalDoc = await rentalRef.get();
              if (rentalDoc.exists) {
                final rentalData = rentalDoc.data() as Map<String, dynamic>;
                final int totalDurationMs = rentalData['totalDurationMs'] ?? 0;
                final int elapsedTimeMs = rentalData['elapsedTimeMs'] ?? 0;
                final int? lastJoinedAt = rentalData['lastJoinedAt'] as int?;

                if (lastJoinedAt != null) {
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  final sessionElapsed = nowMs - lastJoinedAt;
                  final newElapsed = elapsedTimeMs + sessionElapsed;
                  final isExpired = newElapsed >= totalDurationMs;

                  await rentalRef.update({
                    'elapsedTimeMs': newElapsed,
                    'lastJoinedAt': null,
                    'status': isExpired ? 'expired' : 'active',
                  });
                }
              }
            }
          }
        }
      }

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

    _participantCountListeners[roomId] = _participantsRef
        .child(roomId)
        .onValue
        .listen((event) async {
          if (!event.snapshot.exists) {
            await _roomsRef.child('$roomId/participantCount').set(0);
            return;
          }

          final participants = event.snapshot.value;
          if (participants is Map) {
            final actualCount = participants.values
                .where((p) => p is Map && p['isModerator'] != true && p['isStealth'] != true)
                .length;
            final countSnapshot = await _roomsRef
                .child('$roomId/participantCount')
                .get();
            final currentCount = (countSnapshot.value as int?) ?? 0;

            if (currentCount != actualCount) {
              await _roomsRef
                  .child('$roomId/participantCount')
                  .set(actualCount);
            }
          }
        });
  }

  static Future<void> _setupPresence(
    String roomId,
    String userId, {
    required bool isHost,
  }) async {
    final roomRef = _roomsRef.child(roomId);
    final participantRef = _participantsRef.child('$roomId/$userId');

    try {
      if (isHost) {
        // NOTE: Do NOT remove room or participants on temporary disconnect / minimize!
        // Broadcast must stay active when app is minimized or backgrounded.
        // Room will be cleaned up when host explicitly ends stream via deleteRoom().
        await participantRef.child('isOnline').onDisconnect().set(false);
        await roomRef.child('lastActive').set(ServerValue.timestamp);
        _startForegroundHeartbeat(roomId);
      } else {
        await participantRef.child('isOnline').onDisconnect().set(false);
      }
      await participantRef.child('isOnline').set(true);
    } catch (e) {
      debugPrint('Error setting up presence: $e');
      rethrow;
    }
  }

  static void _startForegroundHeartbeat(String roomId) {
    _heartbeatTimers[roomId]?.cancel();
    _heartbeatTimers[roomId] = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
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

      final participantRef = _participantsRef.child('$roomId/${user.uid}');
      await participantRef.child('isOnline').onDisconnect().cancel();
      if (isHost) {
        _heartbeatTimers[roomId]?.cancel();
        _heartbeatTimers[roomId] = null;
      }
    } catch (e) {
      debugPrint('Error pausing presence in audio room: $e');
    }
  }

  static Future<void> resumePresence(
    String roomId,
    String userId, {
    required bool isHost,
  }) async {
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
          await participantRef.child('isOnline').onDisconnect().set(false);
          await participantRef.child('isOnline').set(true);
        }
      }
    } catch (e) {
      debugPrint('Error resuming presence in audio room: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SEAT MANAGEMENT
  // ============================================================================

  static Future<void> leaveSeat(String roomId) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({
      'seatNo': -1,
      'isMuted': true,
      'isApprovedSpeaker': false,
    });
  }

  static Future<void> removeUserFromSeat(String roomId, String targetUserId) async {
    await _participantsRef.child('$roomId/$targetUserId').update({
      'seatNo': -1,
      'isMuted': true,
      'isApprovedSpeaker': false,
    });
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
      isLocked =
          lockedSeatsMap['seat_$newSeatNo'] == true ||
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

    await participantRef.update({
      'seatNo': newSeatNo,
      'isMuted': false,
      'isApprovedSpeaker': true,
    });
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
        isLocked =
            lockedSeatsMap['seat_$newSeatNo'] == true ||
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
    await _participantsRef.child('$roomId/${user.uid}').update({
      'isMuted': newMuteState,
    });
  }

  static Future<void> muteParticipant(
    String roomId,
    String userId,
    bool isMuted,
  ) async {
    await _participantsRef.child('$roomId/$userId').update({
      'isMuted': isMuted,
    });
  }

  static Future<void> lockParticipant(
    String roomId,
    String userId,
    bool isLocked,
  ) async {
    await _participantsRef.child('$roomId/$userId').update({
      'isLocked': isLocked,
    });
  }

  static Future<void> chatMuteParticipant(
    String roomId,
    String userId,
    bool isChatMuted,
  ) async {
    await _participantsRef.child('$roomId/$userId').update({
      'isChatMuted': isChatMuted,
    });
  }

  static Future<void> setAdmin(
    String roomId,
    String userId,
    bool isAdmin,
  ) async {
    await _participantsRef.child('$roomId/$userId').update({
      'isAdmin': isAdmin,
    });
  }

  static Future<void> kickParticipant(String roomId, String userId) async {
    final isMod = await ProfileService.isUserModerator(userId);
    if (isMod) return;
    await _participantsRef.child('$roomId/$userId').remove();
    await _requestsRef.child('$roomId/speaker_requests/$userId').remove();
    await _requestsRef.child('$roomId/cohost_requests/$userId').remove();
  }

  static Stream<DatabaseEvent> getParticipantStream(String roomId, String userId) {
    return _participantsRef.child('$roomId/$userId').onValue;
  }

  static Future<void> blockParticipant(
    String roomId,
    String userId, {
    Duration? duration,
  }) async {
    final isMod = await ProfileService.isUserModerator(userId);
    if (isMod) return;
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
    await _participantsRef.child('$roomId/${user.uid}').update({
      'isCoHost': false,
      'isMuted': false,
      'coHostUntil': null,
    });
  }

  static Future<void> requestToBeCoHost(String roomId) async {
    final user = _auth.currentUser!;
    final userProfileDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

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
    return _requestsRef
        .child('$roomId/cohost_requests')
        .orderByChild('requestedAt')
        .onValue;
  }

  static Future<void> approveCoHostRequest(
    String roomId,
    String requestId,
    String userId,
  ) async {
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

    await participantRef.update({
      'isCoHost': true,
      'seatNo': -1,
      'isMuted': false,
    });
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

    await participantRef.update({
      'isCoHost': true,
      'seatNo': -1,
      'isMuted': false,
    });
    // Also remove any existing requests from this user if any
    await _requestsRef.child('$roomId/cohost_requests/$userId').remove();
    await _requestsRef.child('$roomId/speaker_requests/$userId').remove();
  }

  static Future<void> removeCoHost(String roomId, String userId) async {
    final participantRef = _participantsRef.child('$roomId/$userId');

    // Also mark Firestore rental as expired
    final roomSnap = await _roomsRef.child(roomId).get();
    int seatCount = 8;
    if (roomSnap.exists) {
      final roomData = roomSnap.value as Map<dynamic, dynamic>;
      final String hostId = roomData['hostId'] ?? '';
      seatCount = roomData['seatCount'] ?? 8;
      if (hostId.isNotEmpty) {
        final rentalRef = _firestore.collection('cohost_rentals').doc('${hostId}_$userId');
        await rentalRef.update({
          'status': 'expired',
          'lastJoinedAt': null,
        });
      }
    }

    // Find first available seat (1-seatCount)
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
    for (int i = 1; i <= seatCount; i++) {
      if (!occupiedSeats.contains(i)) {
        targetSeatNo = i;
        break;
      }
    }

    await participantRef.update({
      'isCoHost': false,
      'seatNo': targetSeatNo,
      'isMuted': targetSeatNo == -1,
      'coHostUntil': null,
      'isApprovedSpeaker': false,
    });
  }

  static Future<void> purchaseCoHostSeat({
    required String roomId,
    required String hostId,
    required int coinPrice,
    required Duration duration,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");
    if (user.uid == hostId) throw Exception("Host cannot buy the co-host seat");

    // 1. Verify that co-host seat is not occupied in RTDB
    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var entry in participants.entries) {
        if (entry.key != hostId && entry.value is Map) {
          final participant = entry.value as Map<dynamic, dynamic>;
          if (participant['isCoHost'] == true) {
            final until = participant['coHostUntil'] as int?;
            if (until == null ||
                until > DateTime.now().millisecondsSinceEpoch) {
              throw Exception('Co-host seat is already occupied.');
            }
          }
        }
      }
    }

    // 2. Perform Firestore Transaction for transfer
    await _firestore.runTransaction((transaction) async {
      final senderRef = _usersCollection.doc(user.uid);
      final senderDoc = await transaction.get(senderRef);

      if (!senderDoc.exists) throw Exception("Your profile not found");

      final senderData = senderDoc.data() as Map<String, dynamic>;
      final int currentBalance = senderData['balance'] ?? 0;

      if (currentBalance < coinPrice) {
        throw Exception(
          "Insufficient balance. Need $coinPrice coins, have $currentBalance coins.",
        );
      }

      final hostRef = _usersCollection.doc(hostId);
      final hostDoc = await transaction.get(hostRef);
      if (!hostDoc.exists) throw Exception("Host profile not found");

      // Deduct balance from sender
      transaction.update(senderRef, {
        'balance': FieldValue.increment(-coinPrice),
        'totalSent': FieldValue.increment(coinPrice),
      });

      // Add balance to host
      transaction.update(hostRef, {
        'balance': FieldValue.increment(coinPrice),
        'totalReceived': FieldValue.increment(coinPrice),
      });

      // Record transaction
      final giftDocRef = _firestore.collection('gifting_transactions').doc();
      transaction.set(giftDocRef, {
        'senderId': user.uid,
        'recipientId': hostId,
        'giftValue': coinPrice,
        'category': 'CoHostPurchase',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    // 3. Update Firestore CoHost Rental
    final rentalRef = _firestore.collection('cohost_rentals').doc('${hostId}_${user.uid}');
    final rentalDoc = await rentalRef.get();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (rentalDoc.exists) {
      final data = rentalDoc.data() as Map<String, dynamic>;
      final currentTotal = data['totalDurationMs'] as int? ?? 0;
      final currentElapsed = data['elapsedTimeMs'] as int? ?? 0;
      final status = data['status'] as String? ?? 'expired';

      int newTotal = currentTotal;
      int newElapsed = currentElapsed;
      if (status == 'expired') {
        // Reset elapsed if previous rental expired
        newTotal = duration.inMilliseconds;
        newElapsed = 0;
      } else {
        // Add to existing active rental
        newTotal = currentTotal + duration.inMilliseconds;
      }

      await rentalRef.update({
        'totalDurationMs': newTotal,
        'elapsedTimeMs': newElapsed,
        'lastJoinedAt': nowMs,
        'status': 'active',
      });
    } else {
      await rentalRef.set({
        'hostId': hostId,
        'userId': user.uid,
        'totalDurationMs': duration.inMilliseconds,
        'elapsedTimeMs': 0,
        'lastJoinedAt': nowMs,
        'status': 'active',
      });
    }

    // 4. Update Realtime Database
    final expiryTimeMs = DateTime.now().add(duration).millisecondsSinceEpoch;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');
    await participantRef.update({
      'isCoHost': true,
      'seatNo': -1,
      'isMuted': false,
      'coHostUntil': expiryTimeMs,
    });
  }

  static Future<void> updateCoHostElapsedTime(
    String roomId,
    String hostId,
    String userId,
    int incrementMs,
  ) async {
    try {
      final rentalRef = _firestore.collection('cohost_rentals').doc('${hostId}_$userId');
      final rentalDoc = await rentalRef.get();
      if (rentalDoc.exists) {
        final data = rentalDoc.data() as Map<String, dynamic>;
        final int totalDurationMs = data['totalDurationMs'] ?? 0;
        final int elapsedTimeMs = data['elapsedTimeMs'] ?? 0;
        final int newElapsed = elapsedTimeMs + incrementMs;
        final bool isExpired = newElapsed >= totalDurationMs;

        await rentalRef.update({
          'elapsedTimeMs': newElapsed,
          'lastJoinedAt': DateTime.now().millisecondsSinceEpoch,
          'status': isExpired ? 'expired' : 'active',
        });

        if (isExpired) {
          await removeCoHost(roomId, userId);
        }
      }
    } catch (e) {
      debugPrint("Error updating co-host elapsed time: $e");
    }
  }

  static Future<void> rejectCoHostRequest(
    String roomId,
    String requestId,
  ) async {
    await _requestsRef.child('$roomId/cohost_requests/$requestId').remove();
  }

  // ============================================================================
  // SPEAKER REQUESTS
  // ============================================================================

  static Future<void> requestToBeSpeaker(String roomId) async {
    final user = _auth.currentUser!;
    final userProfileDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

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

  static Future<void> joinCallImmediately(String roomId, {int? targetSeatNo}) async {
    final user = _auth.currentUser!;
    final participantRef = _participantsRef.child('$roomId/${user.uid}');

    // Count current approved speakers (excluding host)
    final roomSnap = await _roomsRef.child(roomId).get();
    if (!roomSnap.exists) throw Exception('Room not found.');
    final roomData = roomSnap.value as Map<dynamic, dynamic>;
    final hostId = roomData['hostId'] ?? '';
    final int seatCount = roomData['seatCount'] ?? 8;

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    int approvedCount = 0;
    final occupiedSeats = <int>{};

    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map) {
          final pUserId = participant['userId'] as String? ?? '';
          final isApproved = participant['isApprovedSpeaker'] == true;
          final isCoHost = participant['isCoHost'] == true;
          final seatNo = participant['seatNo'] as int? ?? -1;

          if (pUserId != hostId && (isApproved || isCoHost)) {
            approvedCount++;
          }
          if (seatNo > 0) {
            occupiedSeats.add(seatNo);
          }
        }
      }
    }

    if (approvedCount >= seatCount) {
      throw Exception('Maximum $seatCount speakers allowed in the call.');
    }

    // If targetSeatNo provided and not occupied, use it.
    // Otherwise find first free seat.
    int assignedSeat;
    if (targetSeatNo != null &&
        targetSeatNo > 0 &&
        targetSeatNo <= seatCount &&
        !occupiedSeats.contains(targetSeatNo)) {
      assignedSeat = targetSeatNo;
    } else {
      assignedSeat = -1;
      for (int i = 1; i <= seatCount; i++) {
        if (!occupiedSeats.contains(i)) {
          assignedSeat = i;
          break;
        }
      }
    }

    await participantRef.update({
      'isApprovedSpeaker': true,
      'isMuted': false,
      'seatNo': assignedSeat,
    });
  }

  static Future<void> inviteOrRemoveParticipantFromCall(
    String roomId,
    String userId,
    bool addToCall,
  ) async {
    final roomSnap = await _roomsRef.child(roomId).get();
    if (!roomSnap.exists) throw Exception('Room not found.');
    final roomData = roomSnap.value as Map<dynamic, dynamic>;
    final hostId = roomData['hostId'] ?? '';
    final int seatCount = roomData['seatCount'] ?? 8;

    final participantRef = _participantsRef.child('$roomId/$userId');

    if (addToCall) {
      final participantsSnapshot = await _participantsRef.child(roomId).get();
      int approvedCount = 0;
      final occupiedSeats = <int>{};

      if (participantsSnapshot.exists) {
        final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
        for (var participant in participants.values) {
          if (participant is Map) {
            final pUserId = participant['userId'] as String? ?? '';
            final isApproved = participant['isApprovedSpeaker'] == true;
            final isCoHost = participant['isCoHost'] == true;
            final seatNo = participant['seatNo'] as int? ?? -1;

            if (pUserId != hostId && (isApproved || isCoHost)) {
              approvedCount++;
            }
            if (seatNo > 0) {
              occupiedSeats.add(seatNo);
            }
          }
        }
      }

      if (approvedCount >= seatCount) {
        throw Exception('Maximum $seatCount speakers allowed in the call.');
      }

      int targetSeatNo = -1;
      for (int i = 1; i <= seatCount; i++) {
        if (!occupiedSeats.contains(i)) {
          targetSeatNo = i;
          break;
        }
      }

      await participantRef.update({
        'isApprovedSpeaker': true,
        'isMuted': false,
        'seatNo': targetSeatNo,
      });
    } else {
      await participantRef.update({
        'isApprovedSpeaker': false,
        'isMuted': true,
        'seatNo': -1,
      });

      // Automatically promote any hidden speakers
      await promoteHiddenSpeakers(roomId);
    }
  }

  // ============================================================================
  // CALL INVITES (Host invites participant to join call / seat)
  // ============================================================================

  static Future<void> sendCallInvite(
    String roomId,
    String targetUserId,
    String inviterName,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _requestsRef.child('$roomId/call_invites/$targetUserId').set({
      'roomId': roomId,
      'hostId': user.uid,
      'hostName': inviterName,
      'targetUserId': targetUserId,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Future<void> cancelCallInvite(
    String roomId,
    String targetUserId,
  ) async {
    await _requestsRef.child('$roomId/call_invites/$targetUserId').remove();
  }

  static Future<void> rejectCallInvite(
    String roomId,
    String targetUserId,
  ) async {
    await _requestsRef.child('$roomId/call_invites/$targetUserId').remove();
  }

  static Future<void> acceptCallInvite(
    String roomId,
    String targetUserId,
  ) async {
    await _requestsRef.child('$roomId/call_invites/$targetUserId').remove();
    await inviteOrRemoveParticipantFromCall(roomId, targetUserId, true);
  }

  static Stream<DatabaseEvent> getCallInviteStream(
    String roomId,
    String userId,
  ) {
    return _requestsRef.child('$roomId/call_invites/$userId').onValue;
  }

  static Future<void> promoteHiddenSpeakers(String roomId) async {
    try {
      final roomSnap = await _roomsRef.child(roomId).get();
      if (!roomSnap.exists) return;
      final roomData = roomSnap.value as Map<dynamic, dynamic>;
      final hostId = roomData['hostId'] ?? '';
      final int seatCount = roomData['seatCount'] ?? 8;

      final participantsSnapshot = await _participantsRef.child(roomId).get();
      if (participantsSnapshot.exists) {
        final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
        final occupiedSeats = <int>{};
        final hiddenSpeakers = <String>[];

        for (var participant in participants.values) {
          if (participant is Map) {
            final pUserId = participant['userId'] as String? ?? '';
            final seatNo = participant['seatNo'] as int? ?? -1;
            final isApproved = participant['isApprovedSpeaker'] == true;

            if (seatNo > 0) {
              occupiedSeats.add(seatNo);
            } else if (isApproved && seatNo == -1 && pUserId != hostId) {
              hiddenSpeakers.add(pUserId);
            }
          }
        }

        for (int i = 1; i <= seatCount; i++) {
          if (!occupiedSeats.contains(i) && hiddenSpeakers.isNotEmpty) {
            final nextHiddenUserId = hiddenSpeakers.removeAt(0);
            await _participantsRef.child('$roomId/$nextHiddenUserId').update({
              'seatNo': i,
            });
            occupiedSeats.add(i);
          }
        }
      }
    } catch (e) {
      debugPrint("Error promoting hidden speakers: $e");
    }
  }

  static Stream<DatabaseEvent> getSpeakerRequestsStream(String roomId) {
    return _requestsRef
        .child('$roomId/speaker_requests')
        .orderByChild('requestedAt')
        .onValue;
  }

  static Future<void> approveSpeakerRequest(
    String roomId,
    String requestId,
    String userId,
  ) async {
    final requestRef = _requestsRef.child(
      '$roomId/speaker_requests/$requestId',
    );
    final participantRef = _participantsRef.child('$roomId/$userId');

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    int approvedSpeakerCount = 0;
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      for (var participant in participants.values) {
        if (participant is Map) {
          final isApproved = participant['isApprovedSpeaker'] == true;
          final seatNo = participant['seatNo'] as int? ?? -1;
          if (isApproved && seatNo == -1) {
            approvedSpeakerCount++;
          }
        }
      }
    }

    if (approvedSpeakerCount >= 15) {
      throw Exception('Maximum 15 approved speakers allowed.');
    }

    debugPrint(
      "DEBUG: approveSpeakerRequest called for roomId: $roomId, requestId: $requestId, userId: $userId",
    );
    await participantRef.update({'isApprovedSpeaker': true, 'isMuted': true});
    await requestRef.remove();
    debugPrint(
      "DEBUG: approveSpeakerRequest successfully completed and updated database",
    );
  }

  static Future<void> seatApprovedParticipant(
    String roomId,
    String userId,
    int seatNo,
  ) async {
    final participantRef = _participantsRef.child('$roomId/$userId');
    await participantRef.update({
      'seatNo': seatNo,
      'isMuted': false,
      'isApprovedSpeaker': true,
    });
  }

  static Future<void> rejectSpeakerRequest(
    String roomId,
    String requestId,
  ) async {
    await _requestsRef.child('$roomId/speaker_requests/$requestId').remove();
  }

  // ============================================================================
  // ROOM SETTINGS
  // ============================================================================

  static Future<void> setRoomNotice(String roomId, String notice) async {
    await _roomsRef.child(roomId).update({'notice': notice});
  }

  static Future<void> updateRoomBackground(
    String roomId,
    String backgroundUrl,
  ) async {
    await _roomsRef.child(roomId).update({
      'backgroundUrl': backgroundUrl,
      'backgroundUpdatedAt': ServerValue.timestamp,
    });
  }

  static Future<void> toggleMoveAllowed(String roomId, bool isAllowed) async {
    await _roomsRef.child(roomId).update({'isMoveAllowed': isAllowed});
  }

  static Future<void> toggleSeatApprovalRequired(
    String roomId,
    bool isRequired,
  ) async {
    await _roomsRef.child(roomId).update({
      'isSeatApprovalRequired': isRequired,
    });
  }

  static Future<void> setOrChangeRoomPassword(
    String roomId,
    String password,
  ) async {
    await _roomsRef.child(roomId).update({
      'isLocked': true,
      'password': password,
    });
  }

  static Future<void> removeRoomPassword(String roomId) async {
    await _roomsRef.child(roomId).update({'isLocked': false, 'password': null});
  }

  static Future<void> toggleRoomLock(String roomId, bool isLocked) async {
    await _roomsRef.child(roomId).update({
      'isLocked': isLocked,
      if (!isLocked) 'password': null,
    });
  }

  static Future<void> lockSeat(String roomId, int seatNo) async {
    await _roomsRef.child('$roomId/lockedSeats/seat_$seatNo').set(true);
  }

  static Future<void> unlockSeat(String roomId, int seatNo) async {
    await _roomsRef.child('$roomId/lockedSeats/seat_$seatNo').remove();
  }

  static Future<void> lockAllSeats(String roomId) async {
    final Map<String, bool> updates = {};
    for (int i = 1; i <= 15; i++) {
      updates['seat_$i'] = true;
    }
    await _roomsRef.child('$roomId/lockedSeats').update(updates);
  }

  static Future<void> unlockAllSeats(String roomId) async {
    await _roomsRef.child('$roomId/lockedSeats').remove();
  }

  static Future<void> updateSeatCount(String roomId, int count) async {
    await _roomsRef.child(roomId).update({'seatCount': count});
  }

  // ============================================================================
  // FAST EVENTS (EMOJIS & GIFTS) - LATEST OVERWRITE ONLY
  // ============================================================================

  static Future<void> sendEmoji(
    String roomId,
    String emojiUrl,
    String emojiName,
  ) async {
    final user = _auth.currentUser!;
    final participantSnapshot = await _participantsRef
        .child('$roomId/${user.uid}')
        .get();

    if (!participantSnapshot.exists) {
      throw Exception('You must join the room first.');
    }

    final participantData = participantSnapshot.value as Map<dynamic, dynamic>;
    final int seatNo = participantData['seatNo'] ?? -1;
    final bool isCoHost = participantData['isCoHost'] ?? false;

    final roomSnapshot = await _roomsRef.child(roomId).get();
    if (!roomSnapshot.exists) throw Exception('Room not found.');

    final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
    final String hostId = roomData['hostId'] ?? '';
    final bool isHost = user.uid == hostId;

    if (!isHost && !isCoHost && seatNo <= 0) {
      throw Exception(
        'Only host, co-host, and seated participants can send emojis.',
      );
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
    return _eventsRef
        .child('$roomId/latest_emoji')
        .onValue; // Changed from onChildAdded
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
    return _eventsRef
        .child('$roomId/latest_gift_notification')
        .onValue; // Changed from onChildAdded
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
    final participantSnapshot = await _participantsRef
        .child('$roomId/${user.uid}')
        .get();

    if (!participantSnapshot.exists) {
      throw Exception('You must join the room first.');
    }

    final participantData = participantSnapshot.value as Map<dynamic, dynamic>;
    String userName = (participantData['userName'] != null && participantData['userName'].toString().isNotEmpty)
        ? participantData['userName'].toString()
        : (user.displayName != null && user.displayName!.isNotEmpty ? user.displayName! : 'User');
    String? userPicture = participantData['userPicture'] ?? user.photoURL;

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

    // Broadcast global gift banner to show everywhere across the app
    GlobalGiftBannerService.broadcastGift(
      senderId: user.uid,
      senderName: userName,
      senderPicture: userPicture,
      receiverName: receiverName ?? 'Host',
      receiverId: receiverId,
      giftValue: giftValue,
      giftImageUrl: giftImageUrl,
      roomId: roomId,
      roomType: 'audioRoom',
    );
  }

  static Stream<DatabaseEvent> getGiftStream(String roomId) {
    return _eventsRef
        .child('$roomId/latest_gift')
        .onValue; // Changed from onChildAdded
  }
}
