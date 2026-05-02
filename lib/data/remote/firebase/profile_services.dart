import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'notification_service.dart';

class SimpleUser {
  final String id;
  final String name;
  final String? pictureUrl;
  final String? currentRoomId;

  SimpleUser({required this.id, required this.name, this.pictureUrl, this.currentRoomId});
}

class LeaderboardUser {
  final String id;
  final String name;
  final String displayId;
  final String? pictureUrl;
  final int totalValue;
  final String? country;
  final String? countryFlagEmoji;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.displayId,
    required this.pictureUrl,
    required this.totalValue,
    this.country,
    this.countryFlagEmoji,
  });
}

class ProfileService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  static final _usersCollection = _firestore.collection('users');
  static final _agencyApplicationsCollection = _firestore.collection('agency_applications');
  static final _hostingApplicationsCollection = _firestore.collection('hosting_applications');
  static final _metadataCollection = _firestore.collection('system_metadata');
  static final _giftsCollection = _firestore.collection('gifting_transactions');

  static Future<void> syncUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _usersCollection.doc(user.uid);
    final counterRef = _metadataCollection.doc('user_counters');

    // Grab the FCM token
    String? fcmToken;
    try {
      fcmToken = await NotificationService.getFCMToken();
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final counterSnapshot = await transaction.get(counterRef);

        bool needsIdAssignment = !userSnapshot.exists;

        if (userSnapshot.exists) {
          final data = userSnapshot.data();
          if (data == null || !data.containsKey('displayId')) {
            needsIdAssignment = true;
          }
        }

        String? newDisplayId;

        if (needsIdAssignment) {
          int currentCount;
          if (counterSnapshot.exists) {
            currentCount = counterSnapshot.data()?['last_assigned_id'] ?? 100000;
          } else {
            currentCount = 100000;
          }

          final nextId = currentCount + 1;
          newDisplayId = nextId.toString();

          transaction.set(counterRef, {'last_assigned_id': nextId}, SetOptions(merge: true));
        }

        if (!userSnapshot.exists) {
          final Map<String, dynamic> profileData = {
            'uid': user.uid,
            'displayId': newDisplayId,
            'displayName': user.displayName,
            'email': user.email,
            'photoUrl': user.photoURL,
            'lastLogin': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'followerCount': 0,
            'followingCount': 0,
            'balance': 0,
            'bio': '',
            'country': 'N/A',
            'countryFlagEmoji': null,
            'gender': null,
            'dob': null,
            'fcmToken': fcmToken,
          };
          transaction.set(userRef, profileData);
        } else {
          final Map<String, dynamic> updateData = {
            'lastLogin': FieldValue.serverTimestamp(),
            'email': user.email
          };

          if (newDisplayId != null) {
            updateData['displayId'] = newDisplayId;
          }
          if (fcmToken != null) {
            updateData['fcmToken'] = fcmToken;
          }

          transaction.update(userRef, updateData);
        }
      });
    } catch (e) {
      debugPrint("Error in syncUserProfile transaction: $e");
      rethrow;
    }
  }

  static Future<String> _uploadProfileImage(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      final uploadTask = ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint("Failed to upload profile image: $e");
      rethrow;
    }
  }

  static Future<String> _uploadApplicationDocument(String userId, File imageFile, String docName) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('application_documents').child(userId).child('${docName}_$timestamp.jpg');

      final uploadTask = ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint("Failed to upload document: $e");
      rethrow;
    }
  }

  static Future<void> updateUserProfile({
    String? displayName,
    String? country,
    String? countryFlagEmoji,
    String? gender,
    DateTime? dob,
    String? bio,
    File? imageFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception("No user logged in");
    }

    final Map<String, dynamic> dataToUpdate = {};

    if (displayName != null) dataToUpdate['displayName'] = displayName;
    if (country != null) dataToUpdate['country'] = country;
    if (countryFlagEmoji != null) dataToUpdate['countryFlagEmoji'] = countryFlagEmoji;
    if (gender != null) dataToUpdate['gender'] = gender;
    if (bio != null) dataToUpdate['bio'] = bio;
    if (dob != null) dataToUpdate['dob'] = Timestamp.fromDate(dob);

    if (imageFile != null) {
      final imageUrl = await _uploadProfileImage(currentUserId, imageFile);
      dataToUpdate['photoUrl'] = imageUrl;
    }

    if (dataToUpdate.isNotEmpty) {
      await _usersCollection.doc(currentUserId).update(dataToUpdate);
    }
  }

  static Future<void> applyForAgency({
    required String agencyName,
    required String holderName,
    required String whatsappNumber,
    required String location,
    String? locationFlag,
    String? reference,
    required File nidFrontFile,
    required File nidBackFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    final nidFrontUrl = await _uploadApplicationDocument(currentUserId, nidFrontFile, 'nid_front');
    final nidBackUrl = await _uploadApplicationDocument(currentUserId, nidBackFile, 'nid_back');

    final Map<String, dynamic> applicationData = {
      'userId': currentUserId,
      'agencyName': agencyName,
      'holderName': holderName,
      'whatsappNumber': whatsappNumber,
      'location': location,
      'locationFlag': locationFlag,
      'reference': reference,
      'nidFrontUrl': nidFrontUrl,
      'nidBackUrl': nidBackUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    };

    await _agencyApplicationsCollection.doc(currentUserId).set(applicationData);
  }

  static Future<void> cancelAgencyApplication() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    await _agencyApplicationsCollection.doc(currentUserId).delete();
  }

  static Future<void> applyForHosting({
    required String idNumber,
    required String hostType,
    required String location,
    String? locationFlag,
    required String agencyCode,
    required File selfieFile,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    final selfieUrl = await _uploadApplicationDocument(currentUserId, selfieFile, 'selfie');

    final Map<String, dynamic> applicationData = {
      'userId': currentUserId,
      'idNumber': idNumber,
      'hostType': hostType,
      'location': location,
      'locationFlag': locationFlag,
      'agencyCode': agencyCode,
      'selfieUrl': selfieUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    };

    await _hostingApplicationsCollection.doc(currentUserId).set(applicationData);
  }

  static Future<DocumentSnapshot> getAgencyApplicationStatus() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");
    return _agencyApplicationsCollection.doc(currentUserId).get();
  }

  static Future<DocumentSnapshot> getHostingApplicationStatus() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");
    return _hostingApplicationsCollection.doc(currentUserId).get();
  }

  static Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    if (userId.isEmpty) {
      return Stream.empty();
    }
    return _usersCollection.doc(userId).snapshots();
  }

  static Future<DocumentSnapshot> getUserProfile(String userId) {
    if (userId.isEmpty) {
      throw Exception("User ID cannot be empty");
    }
    return _usersCollection.doc(userId).get();
  }

  static Stream<QuerySnapshot> getFollowersStream(String userId) {
    if (userId.isEmpty) return Stream.empty();
    return _usersCollection.doc(userId).collection('followers').snapshots();
  }

  static Stream<QuerySnapshot> getFollowingsStream(String userId) {
    if (userId.isEmpty) return Stream.empty();
    return _usersCollection.doc(userId).collection('following').snapshots();
  }

  static Stream<bool> isFollowing(String hostId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || hostId.isEmpty) return Stream.value(false);
    return _usersCollection
        .doc(currentUserId)
        .collection('following')
        .doc(hostId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  static Future<void> followUser(String hostId) async {
    final currentUserId = _auth.currentUser!.uid;

    final batch = _firestore.batch();

    final followingRef = _usersCollection.doc(currentUserId).collection('following').doc(hostId);
    final followerRef = _usersCollection.doc(hostId).collection('followers').doc(currentUserId);
    final hostUserRef = _usersCollection.doc(hostId);
    final currentUserRef = _usersCollection.doc(currentUserId);

    batch.set(followingRef, {'followedAt': FieldValue.serverTimestamp()});
    batch.set(followerRef, {'followedAt': FieldValue.serverTimestamp()});
    batch.update(hostUserRef, {'followerCount': FieldValue.increment(1)});
    batch.update(currentUserRef, {'followingCount': FieldValue.increment(1)});

    await batch.commit();
  }

  static Future<void> unfollowUser(String hostId) async {
    final currentUserId = _auth.currentUser!.uid;

    final batch = _firestore.batch();

    final followingRef = _usersCollection.doc(currentUserId).collection('following').doc(hostId);
    final followerRef = _usersCollection.doc(hostId).collection('followers').doc(currentUserId);
    final hostUserRef = _usersCollection.doc(hostId);
    final currentUserRef = _usersCollection.doc(currentUserId);

    batch.delete(followingRef);
    batch.delete(followerRef);
    batch.update(hostUserRef, {'followerCount': FieldValue.increment(-1)});
    batch.update(currentUserRef, {'followingCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  static Future<List<SimpleUser>> getMutualsList(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final followingSnapshot = await _usersCollection.doc(userId).collection('following').get();

      if (followingSnapshot.docs.isEmpty) {
        return [];
      }

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      final List<Future<SimpleUser?>> mutualCheckFutures = [];

      for (final followingId in followingIds) {
        final futureCheck = _usersCollection.doc(userId).collection('followers').doc(followingId).get().then((
            followerDoc,
            ) async {
          if (followerDoc.exists) {
            return await _fetchUser(followingId);
          }
          return null;
        });

        mutualCheckFutures.add(futureCheck);
      }

      final results = await Future.wait(mutualCheckFutures);
      final mutuals = results.whereType<SimpleUser>().toList();

      return mutuals;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<SimpleUser>> getFollowingList(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final snapshot = await _usersCollection.doc(userId).collection('following').get();

      if (snapshot.docs.isEmpty) return [];

      List<Future<SimpleUser?>> futures = [];
      for (final doc in snapshot.docs) {
        futures.add(_fetchUser(doc.id));
      }

      final results = await Future.wait(futures);
      return results.whereType<SimpleUser>().toList();
    } catch (e) {
      debugPrint("Error in getFollowingList: $e");
      rethrow;
    }
  }

  static Future<List<SimpleUser>> getFollowersList(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final snapshot = await _usersCollection.doc(userId).collection('followers').get();

      if (snapshot.docs.isEmpty) return [];

      List<Future<SimpleUser?>> futures = [];
      for (final doc in snapshot.docs) {
        futures.add(_fetchUser(doc.id));
      }

      final results = await Future.wait(futures);
      return results.whereType<SimpleUser>().toList();
    } catch (e) {
      debugPrint("Error in getFollowersList: $e");
      rethrow;
    }
  }

  static Future<SimpleUser?> _fetchUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return SimpleUser(
        id: doc.id,
        name: data['displayName'] ?? data['hostName'] ?? 'No Name',
        pictureUrl: data['photoUrl'] ?? data['hostPicture'],
        currentRoomId: null,
      );
    } catch (e) {
      debugPrint("Error fetching user $userId: $e");
      return null;
    }
  }

  static Future<void> sendGift({
    required int giftValue,
    required List<String> recipientIds,
    String? giftImageUrl,
    String? roomId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    final int totalCost = giftValue * recipientIds.length;

    try {
      await _firestore.runTransaction((transaction) async {
        final senderRef = _usersCollection.doc(currentUserId);
        final senderDoc = await transaction.get(senderRef);

        if (!senderDoc.exists) throw Exception("Sender profile not found");

        final senderData = senderDoc.data() as Map<String, dynamic>;
        final int currentBalance = senderData['balance'] ?? 0;

        if (currentBalance < totalCost) {
          throw Exception("Insufficient balance. Need $totalCost beans, have $currentBalance beans.");
        }

        transaction.update(senderRef, {
          'balance': FieldValue.increment(-totalCost),
          'totalSent': FieldValue.increment(totalCost),
        });

        for (String recipientId in recipientIds) {
          transaction.update(_usersCollection.doc(recipientId), {
            'diamonds': FieldValue.increment(giftValue),
            'totalReceived': FieldValue.increment(giftValue),
          });

          final giftDocRef = _giftsCollection.doc();
          transaction.set(giftDocRef, {
            'senderId': currentUserId,
            'recipientId': recipientId,
            'giftValue': giftValue,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint("Error in sendGift transaction: $e");
      rethrow;
    }
  }

  static Future<int> getCurrentUserBalance() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    try {
      final doc = await _usersCollection.doc(currentUserId).get();
      if (!doc.exists) return 0;
      final data = doc.data() as Map<String, dynamic>;
      return data['balance'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Stream<int> getCurrentUserBalanceStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(0);

    return _usersCollection.doc(currentUserId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data() as Map<String, dynamic>;
      return data['balance'] ?? 0;
    });
  }

  static Stream<int> getMonthlyReceivedDiamondsStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return _giftsCollection
        .where('recipientId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) {
      int monthlyTotal = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        monthlyTotal += (data['giftValue'] as int? ?? 0);
      }
      return monthlyTotal;
    });
  }

  static Future<int> getMonthlyGiftsReceived({required String userId, required int year, required int month}) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final query = _giftsCollection
          .where('recipientId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(endDate));

      final aggregateQuery = await query.aggregate(sum('giftValue')).get();
      return (aggregateQuery.getSum('giftValue') ?? 0).toInt();
    } catch (e) {
      debugPrint("Error fetching monthly gifts: $e");
      return 0;
    }
  }

  static Future<bool> hasPassword() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final doc = await _usersCollection.doc(currentUserId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      return data.containsKey('password') && data['password'] != null && (data['password'] as String).isNotEmpty;
    } catch (e) {
      debugPrint("Error checking password: $e");
      return false;
    }
  }

  static Future<void> setPassword(String password) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    await _usersCollection.doc(currentUserId).update({'password': password});
  }

  static Future<void> deletePassword() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    await _usersCollection.doc(currentUserId).update({'password': FieldValue.delete()});
  }

  static Future<String?> loginWithDisplayIdAndPassword(String displayId, String password) async {
    try {
      final querySnapshot = await _usersCollection.where('displayId', isEqualTo: displayId).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();

      if (!userData.containsKey('password') || userData['password'] == null) {
        throw Exception('Password not set for this account');
      }

      if (userData['password'] != password) {
        throw Exception('Incorrect password');
      }

      return userDoc.id;
    } catch (e) {
      debugPrint("Error in loginWithDisplayIdAndPassword: $e");
      rethrow;
    }
  }

  static Future<void> savePreferredRoomSkin(String skinUrl) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('No user logged in');

    await _usersCollection.doc(currentUserId).update({'preferredRoomSkin': skinUrl});
  }

  static Future<Map<String, dynamic>> getMonthlyEarnings({
    required String userId,
    required int year,
    required int month,
  }) async {
    try {
      final endDate = DateTime(year, month + 1, 0);

      List<Future<DocumentSnapshot>> historyFutures = [];
      for (int day = 1; day <= endDate.day; day++) {
        final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        historyFutures.add(
          _usersCollection
              .doc(userId)
              .collection('liveHistory')
              .doc(dateKey)
              .get(const GetOptions(source: Source.server)),
        );
      }

      final results = await Future.wait([
        getMonthlyGiftsReceived(userId: userId, year: year, month: month),
        Future.wait(historyFutures),
      ]);

      final totalGifts = results[0] as int;
      final historyDocs = results[1] as List<DocumentSnapshot>;

      int totalAudioMinutes = 0;
      int totalVideoMinutes = 0;
      int validDays = 0;

      for (var historyDoc in historyDocs) {
        if (historyDoc.exists) {
          final data = historyDoc.data() as Map<String, dynamic>;
          final sessions = data['sessions'] as List<dynamic>? ?? [];

          int dailyAudioMinutes = 0;
          int dailyVideoMinutes = 0;
          int dailyValidMinutes = 0;

          for (var session in sessions) {
            final sessionMap = session as Map<String, dynamic>;
            final roomType = sessionMap['roomType'] as String?;
            final durationMinutes = sessionMap['durationMinutes'] as int? ?? 0;

            if (roomType == 'audio') {
              dailyAudioMinutes += durationMinutes;
            } else if (roomType == 'video') {
              dailyVideoMinutes += durationMinutes;
            }

            if (durationMinutes >= 30) {
              dailyValidMinutes += durationMinutes;
            }
          }

          totalAudioMinutes += dailyAudioMinutes;
          totalVideoMinutes += dailyVideoMinutes;

          if (dailyValidMinutes >= 60) {
            validDays++;
          }
        }
      }

      return {
        'validDays': validDays,
        'audioMinutes': totalAudioMinutes,
        'videoMinutes': totalVideoMinutes,
        'revenue': totalGifts,
      };
    } catch (e) {
      debugPrint("Error in getMonthlyEarnings: $e");
      return {'validDays': 0, 'audioMinutes': 0, 'videoMinutes': 0, 'revenue': 0};
    }
  }

  static Future<List<LeaderboardUser>> getTopGifters({
    required String period,
    int limit = 10,
  }) async {
    try {
      final DateTime now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'daily':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      final giftsSnapshot = await _giftsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final Map<String, int> senderTotals = {};

      for (final doc in giftsSnapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final giftValue = data['giftValue'] as int;

        senderTotals[senderId] = (senderTotals[senderId] ?? 0) + giftValue;
      }

      final sortedSenders = senderTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topSenders = sortedSenders.take(limit).toList();

      final List<LeaderboardUser> leaderboard = [];

      for (final entry in topSenders) {
        final userId = entry.key;
        final totalValue = entry.value;

        final userDoc = await _usersCollection.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          leaderboard.add(
            LeaderboardUser(
              id: userId,
              name: userData['displayName'] ?? 'No Name',
              displayId: userData['displayId'] ?? 'N/A',
              pictureUrl: userData['photoUrl'],
              totalValue: totalValue,
              country: userData['country'],
              countryFlagEmoji: userData['countryFlagEmoji'],
            ),
          );
        }
      }

      return leaderboard;
    } catch (e) {
      debugPrint("Error in getTopGifters: $e");
      rethrow;
    }
  }

  static Future<List<LeaderboardUser>> getTopHosts({
    required String period,
    int limit = 10,
  }) async {
    try {
      final DateTime now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'daily':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      final giftsSnapshot = await _giftsCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final Map<String, int> recipientTotals = {};

      for (final doc in giftsSnapshot.docs) {
        final data = doc.data();
        final recipientId = data['recipientId'] as String;
        final giftValue = data['giftValue'] as int;

        recipientTotals[recipientId] = (recipientTotals[recipientId] ?? 0) + giftValue;
      }

      final sortedRecipients = recipientTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topRecipients = sortedRecipients.take(limit).toList();

      final List<LeaderboardUser> leaderboard = [];

      for (final entry in topRecipients) {
        final userId = entry.key;
        final totalValue = entry.value;

        final userDoc = await _usersCollection.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          leaderboard.add(
            LeaderboardUser(
              id: userId,
              name: userData['displayName'] ?? 'No Name',
              displayId: userData['displayId'] ?? 'N/A',
              pictureUrl: userData['photoUrl'],
              totalValue: totalValue,
              country: userData['country'],
              countryFlagEmoji: userData['countryFlagEmoji'],
            ),
          );
        }
      }

      return leaderboard;
    } catch (e) {
      debugPrint("Error in getTopHosts: $e");
      rethrow;
    }
  }
}