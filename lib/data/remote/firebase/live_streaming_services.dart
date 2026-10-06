import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../../ui/live_streaming/bottomsheets/invite_pk_bottomsheet.dart';
import 'profile_services.dart';
import 'global_gift_banner_service.dart';
import '../../../core/services/vip_service.dart';

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
  static final DatabaseReference _participantsRef = _database.ref(
    'live_participants',
  );
  static final DatabaseReference _eventsRef = _database.ref('live_events');
  static final DatabaseReference _requestsRef = _database.ref('live_requests');
  static final DatabaseReference _globalRandomPKRef = _database.ref(
    'globalRandomLivePKInvites',
  );

  static final Map<String, StreamSubscription> _participantCountListeners = {};
  static final Map<String, Timer?> _heartbeatTimers = {};

  // ============================================================================
  // ROOM MANAGEMENT
  // ============================================================================

  static Future<String> createRoom() async {
    final user = _auth.currentUser!;

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

    final userDoc = await _usersCollection.doc(user.uid).get();
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
      await _usersCollection.doc(user.uid).set(userData, SetOptions(merge: true));
    } else {
      userData = userDoc.data() as Map<String, dynamic>;
    }
    final String hostName = userData['displayName'] ?? 'Anonymous';
    final String? hostPicture = userData['photoUrl'];
    final String displayId = userData['displayId'] ?? '';

    final String hostCountry = userData['country'] ?? 'Unknown';

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
      'hasPackage': packagePriority > 0,
      'packagePriority': packagePriority,
      'packageBadgeUrl': packageBadgeUrl,
      'backgroundUrl': roomBackgroundUrl,
      'backgroundUpdatedAt': ServerValue.timestamp,
    });

    // 2. Flattened Participant Data
    final participantRef = _participantsRef.child('$roomId/${user.uid}');
    await participantRef.set({
      'userId': user.uid,
      'displayId': displayId,
      'userName': hostName,
      'userPicture': hostPicture,
      'gender': userData['gender'],
      'joinedAt': ServerValue.timestamp,
      'isOnline': true,
      'isMuted': false,
      'isCameraOn': true,
      'isOnSeat': true,
      'isAdmin': true,
    });

    await _setupPresence(roomId, user.uid, isHost: true);
    
    _setupParticipantCountSync(roomId);

    return roomId;
  }

  static Stream<DatabaseEvent> getAllRooms() =>
      _roomsRef.orderByChild('isActive').equalTo(true).onValue;

  static Future<DataSnapshot> getRoomInfo(String roomId) =>
      _roomsRef.child(roomId).get();

  static Stream<DatabaseEvent> getRoomStream(String roomId) =>
      _roomsRef.child(roomId).onValue;

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

  static Future<void> setRoomMusic(String roomId, String? videoId) async {
    try {
      if (videoId == null) {
        await _roomsRef.child(roomId).child('currentMusicVideoId').remove();
      } else {
        await _roomsRef.child(roomId).update({'currentMusicVideoId': videoId});
      }
    } catch (e) {
      debugPrint('Error setting room music: $e');
    }
  }

  static Stream<DatabaseEvent> getRoomMusicStream(String roomId) {
    return _roomsRef.child('$roomId/currentMusicVideoId').onValue;
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
    String? idEntryUrl;

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      userName = userData['displayName'] ?? userName;
      displayId = userData['displayId'] ?? '';
      userPicture =
          userData['photoUrl'] ?? userData['userPicture'] ?? userPicture;
          
      final addOns = userData['activeAddOns'] as Map<String, dynamic>? ?? {};
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
      final gender = userData['gender'];
      final bool isModerator = ProfileService.checkIsModerator(userData);
      final String? vipType = VipService.resolveVipTypeFromUserData(userData);

      if (isModerator) {
        // Moderator Stealth / Ghost Mode:
        // Do NOT register as participant in RTDB!
        // Ensure no lingering participant entry exists.
        await participantRef.remove();
        return;
      }

      final participantSnapshot = await participantRef.get();
      if (!participantSnapshot.exists) {
        await participantRef.set({
          'userId': user.uid,
          'displayId': displayId,
          'userName': userName,
          'userPicture': userPicture,
          'gender': gender,
          'joinedAt': ServerValue.timestamp,
          'isOnline': true,
          'isMuted': false,
          'isCameraOn': false,
          'isOnSeat': false,
          'isModerator': false,
          'isAdmin': false,
          if (vipType != null) 'vipType': vipType,
          if (idEntryUrl != null) 'idEntryUrl': idEntryUrl,
        });
      } else {
        await participantRef.update({
          'isOnline': true,
          'userName': userName,
          'userPicture': userPicture,
          if (vipType != null) 'vipType': vipType,
          if (idEntryUrl != null) 'idEntryUrl': idEntryUrl,
        });
      }

      await _setupPresence(roomId, user.uid, isHost: false);
    }
  }

  static Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser!;

    try {
      final roomSnapshot = await _roomsRef.child(roomId).get();
      if (roomSnapshot.exists) {
        final roomData = roomSnapshot.value as Map<dynamic, dynamic>;
        if (roomData['hostId'] == user.uid) {
          // If the host is leaving, delete the entire room
          await deleteRoom(roomId);
          return;
        }
      }

      final participantRef = _participantsRef.child('$roomId/${user.uid}');
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
      debugPrint('Error pausing presence: $e');
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
      debugPrint('Error resuming presence: $e');
      rethrow;
    }
  }

  static Future<void> demoteAllParticipantsToViewers(
    String roomId,
    String hostId,
  ) async {
    final pRef = _participantsRef.child(roomId);
    try {
      final snapshot = await pRef.get();
      if (!snapshot.exists) return;
      final participants = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in participants.entries) {
        if (entry.key != hostId) {
          await pRef.child(entry.key).update({
            'isMuted': false,
            'isCameraOn': false,
            'isOnSeat': false,
          });
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

  static Future<void> removeUserFromSeat(String roomId, String targetUserId) async {
    await _participantsRef.child('$roomId/$targetUserId').update({
      'isOnSeat': false,
      'isMuted': false,
      'isCameraOn': false,
    });
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

  static Future<void> kickParticipant(String roomId, String userId) async {
    final isMod = await ProfileService.isUserModerator(userId);
    if (isMod) return;
    await _participantsRef.child('$roomId/$userId').remove();
    await _requestsRef.child('$roomId/join_requests/$userId').remove();
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

  static Future<void> toggleCameraState(String roomId, bool isCameraOn) async {
    final user = _auth.currentUser!;
    await _participantsRef.child('$roomId/${user.uid}').update({
      'isCameraOn': isCameraOn,
    });
  }

  // ============================================================================
  // JOIN REQUESTS
  // ============================================================================

  static Future<void> requestToJoin(String roomId, {String callType = 'audio'}) async {
    final user = _auth.currentUser!;
    final userDoc = await _usersCollection.doc(user.uid).get();

    String userName = user.displayName ?? 'Anonymous';
    String? userPicture = user.photoURL;
    String displayId = '';

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      userName = userData['displayName'] ?? userName;
      displayId = userData['displayId'] ?? '';
      userPicture =
          userData['photoUrl'] ?? userData['userPicture'] ?? userPicture;

      await _requestsRef.child('$roomId/join_requests/${user.uid}').set({
        'userId': user.uid,
        'displayId': displayId,
        'userName': userName,
        'userPicture': userPicture,
        'gender': userData['gender'],
        'callType': callType,
        'requestedAt': ServerValue.timestamp,
      });
    } else {
      await _requestsRef.child('$roomId/join_requests/${user.uid}').set({
        'userId': user.uid,
        'displayId': displayId,
        'userName': userName,
        'userPicture': userPicture,
        'callType': callType,
        'requestedAt': ServerValue.timestamp,
      });
    }
  }

  static Stream<DatabaseEvent> getJoinRequestsStream(String roomId) {
    return _requestsRef
        .child('$roomId/join_requests')
        .orderByChild('requestedAt')
        .onValue;
  }

  static Future<void> approveJoinRequest(
    String roomId,
    String requestId,
    String userId, {
    String callType = 'audio',
  }) async {
    final requestRef = _requestsRef.child('$roomId/join_requests/$requestId');

    final participantsSnapshot = await _participantsRef.child(roomId).get();
    int seatedCount = 0;
    if (participantsSnapshot.exists) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      seatedCount = participants.values
          .where((p) => p is Map && p['isOnSeat'] == true)
          .length;
    }

    if (seatedCount >= 8) throw Exception("The call seats are full.");

    final participantRef = _participantsRef.child('$roomId/$userId');
    await participantRef.update({
      'isOnSeat': true,
      'callType': callType,
      'isMuted': false,
      'isCameraOn': callType == 'video',
    });
    await requestRef.remove();
  }

  static Future<void> rejectJoinRequest(String roomId, String requestId) async {
    await _requestsRef.child('$roomId/join_requests/$requestId').remove();
  }

  /// Ends the call for a participant and resets their seat state
  static Future<void> leaveCall(String roomId, String userId) async {
    final participantRef = _participantsRef.child('$roomId/$userId');
    await participantRef.update({
      'isOnSeat': false,
      'isMuted': true,
      'isCameraOn': false,
      'callType': null,
    });
    await _requestsRef.child('$roomId/join_requests/$userId').remove();
  }

  /// Listen to an individual participant in the live stream
  static Stream<DatabaseEvent> getParticipantStream(String roomId, String userId) {
    return _participantsRef.child('$roomId/$userId').onValue;
  }

  /// Directly joins the call seat without requiring host approval (for King / Royal package VIPs).
  static Future<void> joinCallImmediately(String roomId, {String callType = 'audio'}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in.");

    int seatedCount = 0;
    final participantsSnapshot = await _participantsRef.child(roomId).get();
    if (participantsSnapshot.exists && participantsSnapshot.value is Map) {
      final participants = participantsSnapshot.value as Map<dynamic, dynamic>;
      seatedCount = participants.values
          .where((p) => p is Map && p['isOnSeat'] == true)
          .length;
    }

    if (seatedCount >= 8) throw Exception("The call seats are full.");

    final participantRef = _participantsRef.child('$roomId/${user.uid}');
    await participantRef.update({
      'isOnSeat': true,
      'callType': callType,
      'isMuted': false,
      'isCameraOn': callType == 'video',
    });

    // Remove any pending join request if exists
    await _requestsRef.child('$roomId/join_requests/${user.uid}').remove();
  }

  // ============================================================================
  // MAC ADMIN (Mic / Room Admin) MANAGEMENT
  // ============================================================================

  static Future<void> setAdmin(
    String roomId,
    String userId,
    bool isAdmin,
  ) async {
    await _participantsRef.child('$roomId/$userId').update({
      'isAdmin': isAdmin,
    });
  }

  // ============================================================================
  // CALL INVITES (Host invites participant to join call)
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
    await joinCallImmediately(roomId);
  }

  static Stream<DatabaseEvent> getCallInviteStream(
    String roomId,
    String userId,
  ) {
    return _requestsRef.child('$roomId/call_invites/$userId').onValue;
  }

  // ============================================================================
  // FAST EVENTS (EMOJIS & GIFTS)
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
      throw Exception("You must join the room first.");
    }

    final userDoc = await _usersCollection.doc(user.uid).get();
    String userName =
        userDoc.data()?['displayName'] ?? user.displayName ?? 'Anonymous';

    // OVERWRITE instead of push
    await _eventsRef.child('$roomId/latest_emoji').set({
      'senderId': user.uid,
      'senderName': userName,
      'emojiUrl': emojiUrl,
      'emojiName': emojiName,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Stream<DatabaseEvent> getEmojiStream(String roomId) =>
      _eventsRef.child('$roomId/latest_emoji').onValue;

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
      roomType: 'liveStream',
    );
  }

  static Stream<DatabaseEvent> getGiftStream(String roomId) =>
      _eventsRef.child('$roomId/latest_gift').onValue;

  // ============================================================================
  // USER ROOM QUERIES
  // ============================================================================

  static Future<String?> getUserActiveRoom(String userId) async {
    try {
      final snapshot = await _roomsRef
          .orderByChild('hostId')
          .equalTo(userId)
          .once();
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

      final snapshot = await _roomsRef
          .orderByChild('isActive')
          .equalTo(true)
          .once();
      if (!snapshot.snapshot.exists) return null;

      for (final child in snapshot.snapshot.children) {
        final roomId = child.key.toString();
        final participantSnapshot = await _participantsRef
            .child('$roomId/$userId')
            .get();
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
      final pkState =
          (receiverRoomSnapshot.value as Map)['pkState']
              as Map<dynamic, dynamic>? ??
          {'isPK': false};
      if (pkState['isPK'] == true) {
        throw Exception("User is already in a PK battle.");
      }
    }

    final inviteRef = _requestsRef.child(
      '$receiverRoomId/pk_invites/$senderRoomId',
    );
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
    return _requestsRef
        .child('$myRoomId/pk_invites')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .map((event) {
          if (!event.snapshot.exists) return <PKInvite>[];
          final invitesMap = event.snapshot.value as Map<dynamic, dynamic>;
          return invitesMap.entries
              .map((entry) => PKInvite.fromRTDB(entry.key, entry.value))
              .toList();
        });
  }

  static Stream<List<PKInvite>> getSentPKInvitesStream(String mySenderRoomId) =>
      Stream.value([]);

  static Future<void> acceptPKInvite(String myRoomId, PKInvite invite) async {
    final myRoomRef = _roomsRef.child(myRoomId);
    final senderRoomRef = _roomsRef.child(invite.senderRoomId);
    final myRoomSnapshot = await myRoomRef.get();
    final myRoomData = myRoomSnapshot.value as Map<dynamic, dynamic>;

    final int duration = invite.durationInMinutes;
    final pkEndTime = DateTime.now()
        .add(Duration(minutes: duration))
        .millisecondsSinceEpoch;

    await myRoomRef.update({
      'pkState': {
        'isPK': true,
        'opponentRoomId': invite.senderRoomId,
        'opponentHostId': invite.senderHostId,
        'opponentHostName': invite.senderHostName,
        'role': 'receiver',
        'durationInMinutes': duration,
        'pkEndTime': pkEndTime,
        'scores': {'blue': 0, 'red': 0},
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
        'scores': {'blue': 0, 'red': 0},
      },
    });

    await _requestsRef.child('$myRoomId/pk_invites/${invite.id}').update({
      'status': 'accepted',
    });
  }

  static Future<void> rejectPKInvite(String myRoomId, PKInvite invite) async {
    await _requestsRef.child('$myRoomId/pk_invites/${invite.id}').remove();
  }

  static Future<void> endPKBattle(
    String myRoomId,
    String opponentRoomId,
  ) async {
    await _roomsRef.child(myRoomId).update({
      'pkState': {'isPK': false},
    });
    await _roomsRef.child(opponentRoomId).update({
      'pkState': {'isPK': false},
    });
    await _requestsRef.child('$myRoomId/pk_invites/$opponentRoomId').remove();
    await _requestsRef.child('$opponentRoomId/pk_invites/$myRoomId').remove();
  }

  static Future<void> addPKPoints(
    String roomId,
    String opponentRoomId,
    int points, {
    required bool isBlueTeam,
  }) async {
    if (points <= 0) return;
    try {
      final teamKey = isBlueTeam ? 'blue' : 'red';
      final myScoresRef = _roomsRef.child('$roomId/pkState/scores/$teamKey');
      final oppScoresRef = _roomsRef.child('$opponentRoomId/pkState/scores/$teamKey');

      await myScoresRef.runTransaction((current) {
        final val = (current as num? ?? 0).toInt();
        return Transaction.success(val + points);
      });
      await oppScoresRef.runTransaction((current) {
        final val = (current as num? ?? 0).toInt();
        return Transaction.success(val + points);
      });
    } catch (e) {
      debugPrint('Error updating PK scores: $e');
    }
  }

  // ============================================================================
  // RANDOM PK SYSTEM
  // ============================================================================

  static Future<void> sendGlobalRandomPKInvite(
    String senderRoomId,
    int durationInMinutes,
  ) async {
    final user = _auth.currentUser!;
    final senderRoomSnapshot = await _roomsRef.child(senderRoomId).get();
    if (!senderRoomSnapshot.exists) {
      throw Exception('Your room does not exist.');
    }

    final senderRoomData = senderRoomSnapshot.value as Map<dynamic, dynamic>;
    final pkState =
        senderRoomData['pkState'] as Map<dynamic, dynamic>? ?? {'isPK': false};
    if (pkState['isPK'] == true) {
      throw Exception('You are already in a PK battle.');
    }

    final inviteRef = _globalRandomPKRef.push();
    await inviteRef.set({
      'inviteId': inviteRef.key!,
      'senderRoomId': senderRoomId,
      'senderHostId': user.uid,
      'senderHostName':
          senderRoomData['hostName'] ?? (user.displayName ?? 'Anonymous'),
      'senderHostPicture': senderRoomData['hostPicture'] ?? user.photoURL,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
      'durationInMinutes': durationInMinutes,
      'expiresAt': DateTime.now()
          .add(const Duration(seconds: 7))
          .millisecondsSinceEpoch,
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
      return invitesMap.entries.where((entry) => entry.value is Map).map((
        entry,
      ) {
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

  static Future<void> acceptGlobalRandomPKInvite(
    String roomId,
    PKInvite invite,
  ) async {
    final user = _auth.currentUser!;
    final senderRoomSnapshot = await _roomsRef.child(invite.senderRoomId).get();

    if (!senderRoomSnapshot.exists) {
      throw Exception('Sender room no longer exists.');
    }
    final senderPkState =
        (senderRoomSnapshot.value as Map)['pkState']
            as Map<dynamic, dynamic>? ??
        {'isPK': false};
    if (senderPkState['isPK'] == true) {
      throw Exception('PK already started with someone else.');
    }

    final myRoomSnapshot = await _roomsRef.child(roomId).get();
    if (myRoomSnapshot.exists) {
      final myPkState =
          (myRoomSnapshot.value as Map)['pkState'] as Map<dynamic, dynamic>? ??
          {'isPK': false};
      if (myPkState['isPK'] == true) {
        throw Exception('You are already in a PK battle.');
      }
    }

    await _globalRandomPKRef.child(invite.id).remove();

    final pkEndTime = DateTime.now().add(
      Duration(minutes: invite.durationInMinutes),
    );
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
      'scores': {'blue': 0, 'red': 0},
    });

    await _roomsRef.child(invite.senderRoomId).child('pkState').set({
      'isPK': true,
      'opponentRoomId': roomId,
      'opponentHostId': user.uid,
      'opponentHostName': receiverName,
      'opponentHostPicture': receiverPicture,
      'pkEndTime': pkEndTime.millisecondsSinceEpoch,
      'role': 'sender',
      'scores': {'blue': 0, 'red': 0},
    });
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

  static Future<void> toggleRoomLock(String roomId, bool isLocked) async {
    await _roomsRef.child(roomId).update({
      'isLocked': isLocked,
      if (!isLocked) 'password': null,
    });
  }
}
