import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'profile_services.dart';

class ResellerService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static final _usersCollection = _firestore.collection('users');
  static final _resellerTransactionsCollection = _firestore.collection('reseller_transactions');

  /// Searches for a user by their `displayId` and returns a SimpleUser if found.
  static Future<SimpleUser?> searchUserByDisplayId(String displayId) async {
    try {
      final trimmed = displayId.trim();
      final querySnapshot = await _usersCollection
          .where('displayId', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Fallback: check if the trimmed string is a doc/user ID directly
        final doc = await _usersCollection.doc(trimmed).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          return SimpleUser(
            id: doc.id,
            name: data['displayName'] ?? data['hostName'] ?? 'No Name',
            pictureUrl: data['photoUrl'] ?? data['hostPicture'],
          );
        }
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      return SimpleUser(
        id: doc.id,
        name: data['displayName'] ?? data['hostName'] ?? 'No Name',
        pictureUrl: data['photoUrl'] ?? data['hostPicture'],
      );
    } catch (e) {
      debugPrint("Error searching user by displayId: $e");
      return null;
    }
  }

  /// Transfers `amount` from current user's `balance` to `targetUserId`'s `balance`.
  static Future<void> transferResellerBalance(String targetUserId, int amount) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("No user logged in");

    if (amount <= 0) {
      throw Exception("Amount must be greater than zero");
    }

    if (currentUserId == targetUserId) {
      throw Exception("You cannot transfer balance to yourself");
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final senderRef = _usersCollection.doc(currentUserId);
        final receiverRef = _usersCollection.doc(targetUserId);

        final senderDoc = await transaction.get(senderRef);
        if (!senderDoc.exists) throw Exception("Sender profile not found");

        final receiverDoc = await transaction.get(receiverRef);
        if (!receiverDoc.exists) throw Exception("Receiver profile not found");

        final senderData = senderDoc.data() as Map<String, dynamic>;
        final receiverData = receiverDoc.data() as Map<String, dynamic>;

        final int currentBalance = (senderData['balance'] as num?)?.toInt() ?? 0;

        if (currentBalance < amount) {
          throw Exception("Insufficient balance.");
        }

        // Update Sender
        transaction.update(senderRef, {
          'balance': FieldValue.increment(-amount),
        });

        // Update Receiver
        transaction.update(receiverRef, {
          'balance': FieldValue.increment(amount),
        });

        // Record Transaction
        final transactionDocRef = _resellerTransactionsCollection.doc();
        transaction.set(transactionDocRef, {
          'senderId': currentUserId,
          'receiverId': targetUserId,
          'receiverName': receiverData['displayName'] ?? receiverData['hostName'] ?? 'Unknown',
          'receiverDisplayId': receiverData['displayId'] ?? '',
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'recharge',
        });
      });
    } catch (e) {
      debugPrint("Error in transferResellerBalance transaction: $e");
      rethrow;
    }
  }

  /// Gets a stream of transactions for the current reseller user
  static Stream<List<QueryDocumentSnapshot>> getResellerTransactions() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const Stream.empty();

    return _resellerTransactionsCollection
        .where('senderId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTime = aData['timestamp'] as Timestamp?;
        final bTime = bData['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // Put nulls at the end
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order
      });
      return docs;
    });
  }
}
