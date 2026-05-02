import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // <-- NEW IMPORT
import 'package:firebase_auth/firebase_auth.dart';

/// A simple data model to hold the result from our top earner query.
class TopEarner {
  final String userId;
  final int winningBet;

  TopEarner({required this.userId, required this.winningBet});
}

class FruitsKingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance; // <-- NEW

  // The 6 segments on the wheel, mapping index (0-5) to a fruit type
  final List<String> _wheelSegments = [
    'orange', // 0
    'mango', // 1
    'watermelon', // 2
    'orange', // 3
    'mango', // 4
    'watermelon', // 5
  ];

  /// Listens to the main control document for the Fruits King game.
  Stream<DocumentSnapshot> getGameControlsStream() {
    return _db.collection('fruitsKingControls').doc('main').snapshots();
  }

  /// Listens to the public state of a specific game round.
  Stream<DocumentSnapshot> getGameRoundStream(String roundId) {
    if (roundId == "0") return Stream.empty();
    return _db.collection('fruitsKingRounds').doc(roundId).snapshots();
  }

  /// Listens to the user's *own* bets for the current round.
  Stream<DocumentSnapshot> getMyBetsStream(String roundId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null || roundId == "0") return Stream.empty();
    return _db
        .collection('fruitsKingRounds')
        .doc(roundId)
        .collection('bets')
        .doc(userId)
        .snapshots();
  }

  /// Listens to the last 12 winning results.
  Stream<QuerySnapshot> getGameHistoryStream() {
    return _db
        .collection('fruitsKingRounds')
        .where('phase', isEqualTo: 'result')
        .orderBy('timestamp', descending: true)
        .limit(12)
        .snapshots();
  }

  /// [NEW] Sets the user's entire bet map by calling the 'placeFruitsKingBet' function.
  ///
  /// @param bets: A map containing the user's *total* bet for each fruit.
  /// e.g., { 'orange': 500, 'mango': 1000 }
  Future<void> setBets(String roundId, Map<String, int> bets) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final callable = _functions.httpsCallable('placeFruitsKingBet');

    try {
      // The backend function expects keys like 'betOnOrange'
      await callable.call({
        'roundId': roundId,
        'betOnOrange': bets['orange'] ?? 0,
        'betOnMango': bets['mango'] ?? 0,
        'betOnWatermelon': bets['watermelon'] ?? 0,
      });
      debugPrint("[FRUITS_LOG] setBets successful.");
    } on FirebaseFunctionsException catch (e) {
      debugPrint("[FRUITS_LOG] Error calling placeFruitsKingBet: ${e.code} - ${e.message}");
      // This will pass the error (e.g., "Game is starting up") to the UI
      throw Exception(e.message ?? "An error occurred placing your bet.");
    } catch (e) {
      debugPrint("[FRUITS_LOG] Generic error setting bets: $e");
      throw Exception("An unknown error occurred.");
    }
  }

  /// Fetches the top 3 users who won the most on a specific round.
  Future<List<TopEarner>> getTopEarners(
      String roundId, int winningIndex) async {
    if (roundId == "0") return [];

    // Map the winning index (0-5) to the fruit type ('orange', 'mango', ...)
    final String winningFruit = _wheelSegments[winningIndex];

    try {
      final querySnap = await _db
          .collection('fruitsKingRounds')
          .doc(roundId)
          .collection('bets')
          .orderBy(winningFruit,
          descending: true) // Order by the winning fruit's bet amount
          .limit(3)
          .get();

      final List<TopEarner> earners = [];
      for (final doc in querySnap.docs) {
        final data = doc.data();
        final int winningBet = (data[winningFruit] as int?) ?? 0;

        if (winningBet > 0) {
          earners.add(TopEarner(userId: doc.id, winningBet: winningBet));
        } else {
          break;
        }
      }
      return earners;
    } catch (e) {
      debugPrint("[FRUITS_LOG] ERROR fetching top earners: $e");
      debugPrint("[FRUITS_LOG] This likely means you need to create a Firestore Index.");
      debugPrint(
          "[FRUITS_LOG] Create an index for 'orange', 'mango', and 'watermelon' on the 'fruitsKingRounds/{roundId}/bets' collection.");
      return [];
    }
  }

  /// Adds the user to the game room's participant list
  Future<void> joinGameRoom(Map<String, dynamic> userMap) async {
    final docRef = _db.collection('fruitsKingControls').doc('main');
    await docRef.update({
      'participants': FieldValue.arrayUnion([userMap]),
    });
  }

  /// Removes the user from the game room's participant list
  Future<void> leaveGameRoom(Map<String, dynamic> userMap) async {
    final docRef = _db.collection('fruitsKingControls').doc('main');
    await docRef.update({
      'participants': FieldValue.arrayRemove([userMap]),
    });
  }

  /// Calls the backend to wake up the game if it is paused.
  /// This prevents race conditions by using the transaction-based backend logic.
  Future<void> wakeUpGame() async {
    // 1. Get reference to the new callable function
    final callable = _functions.httpsCallable('wakeUpFruitsKing');

    try {
      // 2. Call the function (no parameters needed)
      final result = await callable.call();
      final data = result.data as Map<dynamic, dynamic>;
      debugPrint("[FRUITS_LOG] Wake up response: ${data['message']}");

    } on FirebaseFunctionsException catch (e) {
      debugPrint("[FRUITS_LOG] Error calling wakeUpFruitsKing: ${e.code} - ${e.message}");
      throw Exception(e.message ?? "Failed to start the game.");
    } catch (e) {
      debugPrint("[FRUITS_LOG] Generic error waking up game: $e");
      throw Exception("An unknown error occurred.");
    }
  }
}