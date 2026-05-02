import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppServices {
  static final _firestore = FirebaseFirestore.instance;

  // Collection Reference
  static final _appSettingsCollection = _firestore.collection('appSettings');

  // The specific document ID where we store Zego keys
  static const String _zegoDocId = 'zego_config';

  /// Fetches the Zego App ID as an integer
  static Future<int> getZegoAppId() async {
    try {
      final doc = await _appSettingsCollection.doc(_zegoDocId).get();

      if (doc.exists && doc.data() != null) {
        // Firestore stores numbers as 'num', so we safe cast to int
        return (doc.data()!['appId'] as num).toInt();
      } else {
        throw Exception("Zego config document not found!");
      }
    } catch (e) {
      debugPrint("Error fetching Zego App ID: $e");
      // Return a default value or rethrow based on your needs
      rethrow;
    }
  }

  /// Fetches the Zego App Sign as a String
  static Future<String> getZegoAppSign() async {
    try {
      final doc = await _appSettingsCollection.doc(_zegoDocId).get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['appSign'] as String;
      } else {
        throw Exception("Zego config document not found!");
      }
    } catch (e) {
      debugPrint("Error fetching Zego App Sign: $e");
      rethrow;
    }
  }

  /// Optional: Get both at once to save a database read
  static Future<Map<String, dynamic>> getZegoConfig() async {
    final doc = await _appSettingsCollection.doc(_zegoDocId).get();
    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>;
    }
    throw Exception("Zego config not found");
  }
}
