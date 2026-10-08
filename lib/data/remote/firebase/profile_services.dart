import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final int totalSent;
  final String? country;
  final String? countryFlagEmoji;

  LeaderboardUser({
    required this.id,
    required this.name,
    required this.displayId,
    required this.pictureUrl,
    required this.totalValue,
    this.totalSent = 0,
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

  static bool? _cachedIsModerator;
  static String? _cachedUserId;

  static bool checkIsModerator(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = data['role']?.toString().toLowerCase().trim() ?? '';
    final roles = data['roles'];
    bool hasRole = role == 'moderator' ||
        role == 'mod' ||
        role == 'admin' ||
        role == 'superadmin' ||
        role == 'super_admin' ||
        role == 'administrator';

    if (!hasRole && roles is List) {
      hasRole = roles.any((r) {
        final rStr = r.toString().toLowerCase().trim();
        return rStr == 'moderator' ||
            rStr == 'mod' ||
            rStr == 'admin' ||
            rStr == 'superadmin' ||
            rStr == 'super_admin';
      });
    }

    return hasRole ||
        data['isModerator'] == true ||
        data['ismoderator'] == true ||
        data['isAdmin'] == true ||
        data['isadmin'] == true ||
        data['isSuperAdmin'] == true ||
        data['issuperadmin'] == true;
  }

  static Future<bool> isUserModerator(String userId) async {
    if (_cachedUserId == userId && _cachedIsModerator != null) {
      return _cachedIsModerator!;
    }
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final isMod = checkIsModerator(data);
      _cachedUserId = userId;
      _cachedIsModerator = isMod;
      return isMod;
    } catch (e) {
      debugPrint('Error checking moderator status: $e');
      return false;
    }
  }

  static void clearModeratorCache() {
    _cachedIsModerator = null;
    _cachedUserId = null;
  }

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
            'diamonds': 0,
            'totalSent': 0,
            'totalReceived': 0,
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

  /// Uploads an image file to PigoLive API and returns the secure URL.
  /// Uses an explicit http.Client with close() to prevent Android connection reset errors.
  static Future<String> _uploadImage(File imageFile) async {
    final uri = Uri.parse('https://api.pigolive.top/api/upload');

    // Use an explicit client so we can close it properly — this prevents
    // "Connection reset by peer (errno=104)" on Android.
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await client.send(request);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
        final success = jsonData['success'] as bool? ?? false;
        final url = jsonData['url'] as String?;
        
        if (!success || url == null || url.isEmpty) {
          throw Exception('Upload failed or returned no URL');
        }
        return url;
      } else {
        debugPrint('Upload failed (${streamedResponse.statusCode}): $responseBody');
        throw Exception('Upload failed with status ${streamedResponse.statusCode}');
      }
    } finally {
      client.close(); // Always release the connection
    }
  }

  // Updates the user profile in Firestore
  static Future<void> updateUserProfile({
    String? displayName,
    String? whatsappNumber,
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
    if (whatsappNumber != null) dataToUpdate['whatsappNumber'] = whatsappNumber;
    if (country != null) dataToUpdate['country'] = country;
    if (countryFlagEmoji != null) dataToUpdate['countryFlagEmoji'] = countryFlagEmoji;
    if (gender != null) dataToUpdate['gender'] = gender;
    if (bio != null) dataToUpdate['bio'] = bio;
    if (dob != null) dataToUpdate['dob'] = Timestamp.fromDate(dob);

    if (imageFile != null) {
      // First, get the current user profile to find the old image URL
      final userDoc = await _usersCollection.doc(currentUserId).get();
      String? oldImageUrl;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        oldImageUrl = data['photoUrl'] as String?;
      }

      // Upload new image using custom API
      final newImageUrl = await _uploadImage(imageFile);
      
      dataToUpdate['photoUrl'] = newImageUrl;

      // Delete the old image from Firebase Storage if it exists and is a Firebase Storage URL
      if (oldImageUrl != null && oldImageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final oldImageRef = _storage.refFromURL(oldImageUrl);
          await oldImageRef.delete();
        } catch (e) {
          debugPrint("Failed to delete old profile image: $e");
        }
      }
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

    // Upload both NID images in parallel
    final results = await Future.wait([
      _uploadImage(nidFrontFile),
      _uploadImage(nidBackFile),
    ]);
    final nidFrontUrl = results[0];
    final nidBackUrl = results[1];

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

  static Future<void> cancelHostingApplication() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    await _hostingApplicationsCollection.doc(currentUserId).delete();
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

    // Upload selfie
    final selfieUrl = await _uploadImage(selfieFile);

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

    // Check if host/agency/user is locked
    final bool isSenderLocked = await isCurrentUserLocked();
    if (isSenderLocked) {
      throw Exception("Your account is locked. You cannot send gifts.");
    }

    final int totalCost = giftValue * recipientIds.length;
    
    int hostBasicShare = 88;
    int agencyCommission = 10;
    int adminCommission = 2;
    try {
      final configDoc = await _firestore.collection('appSettings').doc('Commission_config').get();
      if (configDoc.exists && configDoc.data() != null) {
        final data = configDoc.data()!;
        if (data['hostBasicShare'] != null) {
          hostBasicShare = (data['hostBasicShare'] as num).toInt();
        }
        if (data['agencyCommission'] != null) {
          agencyCommission = (data['agencyCommission'] as num).toInt();
        }
        if (data['adminCommission'] != null) {
          adminCommission = (data['adminCommission'] as num).toInt();
        }
      }
    } catch (e) {
      debugPrint("Error fetching Commission_config: $e");
    }

    try {
      // ── PHASE 1: collect all DocumentRefs + read all docs OUTSIDE the transaction ──
      final adminRef = _firestore.collection('totaldiamond').doc('diamondcalculation');

      // Pre-read every recipient + their agency (if host)
      final List<Map<String, dynamic>> recipientInfos = [];
      for (final recipientId in recipientIds) {
        final recipientDoc = await _usersCollection.doc(recipientId).get();
        if (!recipientDoc.exists) continue;
        final recipientData = recipientDoc.data() as Map<String, dynamic>;
        final bool isHost = recipientData['isHost'] == true || 
                            recipientData['ishost'] == true || 
                            recipientData['role'] == 'host';

        // Try multiple field names for agency reference
        final String? agencyCode = (recipientData['agencyCode'] 
            ?? recipientData['agencyId'])?.toString();

        String? resolvedAgencyDocId;
        DocumentSnapshot<Map<String, dynamic>>? agencySnap;
        String? resolvedAgencyOwnerId;

        if (isHost) {
          if (agencyCode != null && agencyCode.isNotEmpty) {
            // Try direct document lookup first
            final directSnap = await _firestore
                .collection('agencies')
                .doc(agencyCode)
                .get();
            if (directSnap.exists) {
              resolvedAgencyDocId = agencyCode;
              agencySnap = directSnap;
            }
          }
          // Fallback: search agencies where hosts array contains recipientId
          if (resolvedAgencyDocId == null) {
            final agencyQuery = await _firestore
                .collection('agencies')
                .where('hosts', arrayContains: recipientId)
                .limit(1)
                .get();
            if (agencyQuery.docs.isNotEmpty) {
              resolvedAgencyDocId = agencyQuery.docs.first.id;
              agencySnap = agencyQuery.docs.first;
            }
          }

          if (agencySnap != null && agencySnap.exists) {
            final agData = agencySnap.data() as Map<String, dynamic>;
            resolvedAgencyOwnerId = (agData['ownerId'] ?? agData['userId'])?.toString();
          }

          // Fallback: lookup owner in agency_applications if ownerId is missing on agencies doc
          if ((resolvedAgencyOwnerId == null || resolvedAgencyOwnerId.isEmpty) && resolvedAgencyDocId != null) {
            final appQuery = await _firestore
                .collection('agency_applications')
                .where('agencyId', isEqualTo: int.tryParse(resolvedAgencyDocId) ?? resolvedAgencyDocId)
                .limit(1)
                .get();
            if (appQuery.docs.isNotEmpty) {
              final appData = appQuery.docs.first.data();
              resolvedAgencyOwnerId = (appData['userId'] ?? appData['ownerId'])?.toString();
            }
          }

          // Fallback: recipient's own data
          if (resolvedAgencyOwnerId == null || resolvedAgencyOwnerId.isEmpty) {
            resolvedAgencyOwnerId = (recipientData['agencyOwnerId'] ?? recipientData['agencyUserId'])?.toString();
          }

          debugPrint('sendGift: host=$recipientId, agencyCode=$agencyCode, resolvedAgency=$resolvedAgencyDocId, agencyOwner=$resolvedAgencyOwnerId');
        }

        recipientInfos.add({
          'id': recipientId,
          'data': recipientData,
          'isHost': isHost,
          'agencyId': resolvedAgencyDocId,
          'agencySnap': agencySnap,
          'agencyOwnerId': resolvedAgencyOwnerId,
        });
      }

      // ── PHASE 2: run the transaction (reads first, then writes) ──
      await _firestore.runTransaction((transaction) async {
        final senderRef = _usersCollection.doc(currentUserId);
        final senderDoc = await transaction.get(senderRef);

        if (!senderDoc.exists) throw Exception("Sender profile not found");

        final senderData = senderDoc.data() as Map<String, dynamic>;
        final bool isLocked = senderData['islock'] == true ||
            senderData['isLock'] == true ||
            senderData['isLocked'] == true;
        if (isLocked) {
          throw Exception("Your account is locked. You cannot send gifts.");
        }

        final num currentBalanceNum = senderData['balance'] ?? 0;
        final double currentBalance = currentBalanceNum.toDouble();

        if (currentBalance < totalCost) {
          throw Exception("Insufficient balance. Need $totalCost beans, have $currentBalance beans.");
        }

        // Re-read admin doc inside transaction (must be first)
        final adminDocTxn = await transaction.get(adminRef);

        // Re-read agency docs inside transaction (must be before any write)
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> agencySnapshots = {};
        for (final info in recipientInfos) {
          if (info['isHost'] == true && info['agencyId'] != null) {
            final agencyRef = _firestore.collection('agencies').doc(info['agencyId'] as String);
            agencySnapshots[info['agencyId'] as String] = await transaction.get(agencyRef);
          }
        }

        // Re-read agency owner user docs inside transaction (must be before any write)
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> agencyOwnerSnapshots = {};
        for (final info in recipientInfos) {
          final String? ownerId = info['agencyOwnerId'] as String?;
          if (info['isHost'] == true && ownerId != null && ownerId.isNotEmpty && !agencyOwnerSnapshots.containsKey(ownerId)) {
            final ownerRef = _usersCollection.doc(ownerId);
            final ownerSnap = await transaction.get(ownerRef);
            if (ownerSnap.exists) {
              agencyOwnerSnapshots[ownerId] = ownerSnap;
            }
          }
        }

        // ── All reads done – now do all writes ──

        transaction.update(senderRef, {
          'balance': FieldValue.increment(-totalCost),
          'totalSent': FieldValue.increment(totalCost),
        });

        double totalAdminShare = 0.0;

        for (final info in recipientInfos) {
          final String recipientId = info['id'] as String;
          final bool isHost = info['isHost'] as bool;
          final String? agencyId = info['agencyId'] as String?;
          final recipientRef = _usersCollection.doc(recipientId);

          double recipientShare = 0;
          double adminShare = 0;
          double agencyShare = 0;

          if (!isHost) {
            recipientShare = (giftValue * (100 - adminCommission) / 100).toDouble();
            adminShare = giftValue - recipientShare;
          } else {
            recipientShare = (giftValue * hostBasicShare / 100).toDouble();
            agencyShare = (giftValue * agencyCommission / 100).toDouble();
            adminShare = giftValue - recipientShare - agencyShare;
            if (adminShare < 0) adminShare = 0;
          }

          totalAdminShare += adminShare;

          transaction.update(recipientRef, {
            'balance': FieldValue.increment(recipientShare),
            'totalReceived': FieldValue.increment(recipientShare),
          });

          // Agency Share write (use pre-read snapshot)
          if (isHost && agencyShare > 0 && agencyId != null && agencyId.isNotEmpty) {
            final agencySnap = agencySnapshots[agencyId];
            if (agencySnap != null && agencySnap.exists) {
              final agencyData = agencySnap.data() as Map<String, dynamic>;
              final currentCommStr = agencyData['agencycommision']?.toString() ?? '0';
              final double currentComm = double.tryParse(currentCommStr) ?? 0.0;
              final agencyRef = _firestore.collection('agencies').doc(agencyId);
              transaction.update(agencyRef, {
                'agencycommision': (currentComm + agencyShare).toStringAsFixed(2),
              });
            }
          }

          final giftDocRef = _giftsCollection.doc();
          transaction.set(giftDocRef, {
            'senderId': currentUserId,
            'recipientId': recipientId,
            'giftValue': giftValue,
            'hostShare': recipientShare,
            'agencyShare': agencyShare,
            if (info['agencyOwnerId'] != null) 'agencyOwnerId': info['agencyOwnerId'],
            'adminShare': adminShare,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        // ── Agency user balance writes (add agency commission to agency user's balance) ──
        final Map<String, double> totalAgencyShareByOwner = {};
        for (final info in recipientInfos) {
          final bool isHost = info['isHost'] as bool;
          final String? ownerId = info['agencyOwnerId'] as String?;
          if (isHost && ownerId != null && ownerId.isNotEmpty) {
            final double agencyShare = (giftValue * agencyCommission / 100).toDouble();
            totalAgencyShareByOwner[ownerId] = (totalAgencyShareByOwner[ownerId] ?? 0.0) + agencyShare;
          }
        }

        for (final entry in totalAgencyShareByOwner.entries) {
          final String ownerId = entry.key;
          final double totalShare = entry.value;
          if (totalShare > 0 && agencyOwnerSnapshots.containsKey(ownerId)) {
            final agencyUserRef = _usersCollection.doc(ownerId);
            transaction.update(agencyUserRef, {
              'balance': FieldValue.increment(totalShare),
              'totalReceived': FieldValue.increment(totalShare),
            });
          }
        }

        // Admin Share write – one write for the entire transaction (use pre-read adminDocTxn)
        if (totalAdminShare > 0) {
          if (adminDocTxn.exists) {
            final adminData = adminDocTxn.data() as Map<String, dynamic>;
            final currentTotalDiamondStr = adminData['totaldiamond']?.toString() ?? '0';
            final double currentTotalDiamond = double.tryParse(currentTotalDiamondStr) ?? 0.0;
            transaction.update(adminRef, {
              'totaldiamond': (currentTotalDiamond + totalAdminShare).toStringAsFixed(2),
            });
          } else {
            transaction.set(adminRef, {
              'totaldiamond': totalAdminShare.toStringAsFixed(2),
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error in sendGift transaction: $e");
      rethrow;
    }
  }

  static Future<void> sendRocketGift({
    required int totalCoins,
    required List<String> recipientIds,
    String? roomId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    // Check if host/agency/user is locked
    final bool isSenderLocked = await isCurrentUserLocked();
    if (isSenderLocked) {
      throw Exception("Your account is locked. You cannot send gifts.");
    }

    // 50% vanish, 50% distribute
    final int distributionAmount = totalCoins ~/ 2;
    final int sharePerRecipient = recipientIds.isNotEmpty ? distributionAmount ~/ recipientIds.length : 0;

    try {
      await _firestore.runTransaction((transaction) async {
        final senderRef = _usersCollection.doc(currentUserId);
        final senderDoc = await transaction.get(senderRef);

        if (!senderDoc.exists) throw Exception("Sender profile not found");

        final senderData = senderDoc.data() as Map<String, dynamic>;
        final bool isLocked = senderData['islock'] == true ||
            senderData['isLock'] == true ||
            senderData['isLocked'] == true;
        if (isLocked) {
          throw Exception("Your account is locked. You cannot send gifts.");
        }

        final int currentBalance = senderData['balance'] ?? 0;

        if (currentBalance < totalCoins) {
          throw Exception("Insufficient balance. Need $totalCoins beans, have $currentBalance beans.");
        }

        // Deduct totalCoins from sender
        transaction.update(senderRef, {
          'balance': FieldValue.increment(-totalCoins),
          'totalSent': FieldValue.increment(totalCoins),
        });

        // Add sharePerRecipient to each recipient
        if (sharePerRecipient > 0) {
          for (String recipientId in recipientIds) {
            transaction.update(_usersCollection.doc(recipientId), {
              'diamonds': FieldValue.increment(sharePerRecipient),
              'totalReceived': FieldValue.increment(sharePerRecipient),
            });

            final giftDocRef = _giftsCollection.doc();
            transaction.set(giftDocRef, {
              'senderId': currentUserId,
              'recipientId': recipientId,
              'giftValue': sharePerRecipient,
              'category': 'RocketShare',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error in sendRocketGift transaction: $e");
      rethrow;
    }
  }

  static int _parseBalanceValue(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  static Future<int> getCurrentUserBalance() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0;

    try {
      final doc = await _usersCollection.doc(currentUserId).get();
      if (!doc.exists) return 0;
      final data = doc.data() as Map<String, dynamic>;
      final int b = _parseBalanceValue(data['balance']);
      if (b > 0) return b;
      final int d = _parseBalanceValue(data['diamonds']);
      if (d > 0) return d;
      final int bn = _parseBalanceValue(data['beans']);
      if (bn > 0) return bn;
      return b;
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
      final int b = _parseBalanceValue(data['balance']);
      if (b > 0) return b;
      final int d = _parseBalanceValue(data['diamonds']);
      if (d > 0) return d;
      final int bn = _parseBalanceValue(data['beans']);
      if (bn > 0) return bn;
      return b;
    });
  }

  static Future<bool> isCurrentUserLocked() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final doc = await _usersCollection.doc(currentUserId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;

      // 1. Direct lock check on user document
      if (data['islock'] == true ||
          data['isLock'] == true ||
          data['isLocked'] == true) {
        return true;
      }

      // 2. Agency role lock check
      final bool isAgency = data['role'] == 'agency' ||
          data['isAgency'] == true ||
          data['isagency'] == true;

      final agencyId = (data['agencyId'] ?? data['agencyCode'])?.toString();

      if (isAgency || (agencyId != null && agencyId.isNotEmpty)) {
        // Check agency document by agencyId
        if (agencyId != null && agencyId.isNotEmpty) {
          final agencyDoc = await _firestore.collection('agencies').doc(agencyId).get();
          if (agencyDoc.exists) {
            final agData = agencyDoc.data() ?? {};
            if (agData['islock'] == true ||
                agData['isLock'] == true ||
                agData['isLocked'] == true) {
              return true;
            }
          }
        }

        // Check agencies collection by ownerId
        final ownerAgenciesQuery = await _firestore
            .collection('agencies')
            .where('ownerId', isEqualTo: currentUserId)
            .limit(1)
            .get();
        if (ownerAgenciesQuery.docs.isNotEmpty) {
          final agData = ownerAgenciesQuery.docs.first.data();
          if (agData['islock'] == true ||
              agData['isLock'] == true ||
              agData['isLocked'] == true) {
            return true;
          }
        }

        // Check agency_applications collection by userId
        final appQuery = await _firestore
            .collection('agency_applications')
            .where('userId', isEqualTo: currentUserId)
            .limit(1)
            .get();
        if (appQuery.docs.isNotEmpty) {
          final appData = appQuery.docs.first.data();
          if (appData['islock'] == true ||
              appData['isLock'] == true ||
              appData['isLocked'] == true) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error checking isCurrentUserLocked: $e");
      return false;
    }
  }

  static Stream<bool> getCurrentUserLockStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(false);

    return _usersCollection.doc(currentUserId).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return false;
      return await isCurrentUserLocked();
    });
  }

  static Future<void> topUpBalance(int amount) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");
    await _usersCollection.doc(currentUserId).update({
      'balance': FieldValue.increment(amount),
    });
  }

  static Future<void> exchangeDiamondsToBeans(int diamondsToExchange) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");
    if (diamondsToExchange <= 0) throw Exception("Invalid amount");

    // Fetch dynamic exchange rate from Firestore
    double exchangeRatePct = 60.0; // fallback
    try {
      final configDoc = await _firestore
          .collection('appSettings')
          .doc('Commission_config')
          .get();
      if (configDoc.exists) {
        final raw = configDoc.data()?['exchangerate'];
        final parsed = double.tryParse(raw?.toString() ?? '');
        if (parsed != null) exchangeRatePct = parsed;
      }
    } catch (e) {
      debugPrint('Failed to fetch exchange rate: $e');
    }

    await _firestore.runTransaction((transaction) async {
      final userRef = _usersCollection.doc(currentUserId);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) throw Exception("User profile not found");

      final data = userDoc.data() as Map<String, dynamic>;
      final currentDiamonds = data['diamonds'] ?? 0;

      if (currentDiamonds < diamondsToExchange) {
        throw Exception("Insufficient earning coins (diamonds).");
      }

      final beansToAdd = (diamondsToExchange * exchangeRatePct / 100).toInt();

      transaction.update(userRef, {
        'diamonds': FieldValue.increment(-diamondsToExchange),
        'balance': FieldValue.increment(beansToAdd),
      });
    });
  }


  static Stream<int> getUserDiamondsStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data() as Map<String, dynamic>;
      final int b = _parseBalanceValue(data['balance']);
      if (b > 0) return b;
      final int d = _parseBalanceValue(data['diamonds']);
      if (d > 0) return d;
      final int bn = _parseBalanceValue(data['beans']);
      if (bn > 0) return bn;
      return b;
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

  static Future<List<LeaderboardUser>> getTopFansForHost({
    required String hostId,
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

      // Fetch all gifts for this recipient and filter locally to avoid composite index requirements
      final giftsSnapshot = await _giftsCollection
          .where('recipientId', isEqualTo: hostId)
          .get();

      final Map<String, int> senderTotals = {};

      for (final doc in giftsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          if (date.isBefore(startDate)) {
            continue; // Skip gifts before the start date
          }
        }
        
        final senderId = data['senderId'] as String;
        final giftValue = (data['giftValue'] as num?)?.toInt() ?? 0;

        senderTotals[senderId] = (senderTotals[senderId] ?? 0) + giftValue;
      }

      final sortedSenders = senderTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topSenders = sortedSenders.take(limit).toList();

      final List<LeaderboardUser> leaderboard = [];

      for (final entry in topSenders) {
        final userId = entry.key;
        final periodValue = entry.value;

        final userDoc = await _usersCollection.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          leaderboard.add(
            LeaderboardUser(
              id: userId,
              name: userData['displayName'] ?? 'No Name',
              displayId: userData['displayId'] ?? 'N/A',
              pictureUrl: userData['photoUrl'],
              totalValue: periodValue,
              totalSent: userData['totalSent'] ?? 0,
              country: userData['country'],
              countryFlagEmoji: userData['countryFlagEmoji'],
            ),
          );
        }
      }

      return leaderboard;
    } catch (e) {
      debugPrint("Error in getTopFansForHost: $e");
      rethrow;
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
              totalSent: userData['totalSent'] ?? 0,
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
              totalSent: userData['totalSent'] ?? 0,
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


  // --- Restored Missing Methods ---

  static Future<void> syncFollowingNotificationTopics() async {}
  static Future<Map<String, dynamic>> getSystemTags() async { return {}; }
  static Future<String> getLevelImageUrl(int level) async { return ''; }
  
  static Future<dynamic> getCoinSellerApplicationStatus() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");
    return await _firestore.collection('coin_seller_applications').doc(currentUserId).get();
  }
  
  static Future<void> applyForCoinSeller({required String name, required String whatsappNumber}) async {}
  static Future<void> cancelCoinSellerApplication() async {}
  static Future<void> transferCoinsAsReseller(String targetDisplayId, int amount) async {}
  static Future<void> requestCoinsAsReseller(int amount, String note) async {}
  static Future<String> uploadImageApi(File file) => _uploadImage(file);
  static Future<String> getAgencyName(String agencyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('agencies').doc(agencyId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['agencyName'] ?? data['name'] ?? data['holderName'] ?? data['agencyname'] ?? '').toString();
      }
    } catch (e) {
      debugPrint("Error fetching agency name: $e");
    }
    return '';
  }

  /// Checks whether a user has an active, unexpired King or Royal package.
  static Future<bool> hasKingOrRoyalPackage(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      // 1. Check direct package fields
      final String directPkg = (data['activePackage'] ?? data['package'] ?? '').toString().toLowerCase();
      if (directPkg.contains('royal') || directPkg.contains('king')) {
        return true;
      }

      // 2. Check activeAddOns map
      if (data.containsKey('activeAddOns')) {
        final addOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};
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

              if (fullStr.contains('royal') || fullStr.contains('king')) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking royal/king package: $e");
    }
    return false;
  }
}