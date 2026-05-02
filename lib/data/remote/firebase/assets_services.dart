import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmojiModel {
  final String id;
  final String name;
  final String imageUrl;

  EmojiModel({required this.id, required this.name, required this.imageUrl});

  factory EmojiModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmojiModel(id: doc.id, name: data['name'] ?? '', imageUrl: data['imageURL'] ?? '');
  }
}

// NEW: Gift Model
class GiftModel {
  final String id;
  final String name;
  final String imageUrl;
  final String iconUrl;
  final int value;
  final String category;

  GiftModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.iconUrl,
    required this.value,
    required this.category,
  });

  factory GiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftModel(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageURL'] ?? '',
      iconUrl: data['iconURL'] ?? '',
      value: data['value'] ?? 0,
      category: data['category'] ?? 'Uncategorized',
    );
  }
}

class AssetsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _emojisCollection = _firestore.collection('emojis');
  static final CollectionReference _giftsCollection = _firestore.collection('gifts');

  // Stream of Emojis from Firestore
  static Stream<List<EmojiModel>> getEmojis() {
    return _emojisCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EmojiModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Stream of Gifts from Firestore
  static Stream<List<GiftModel>> getGifts() {
    return _giftsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Get gifts by category
  static Stream<List<GiftModel>> getGiftsByCategory(String category) {
    return _giftsCollection.where('category', isEqualTo: category).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Get all unique gift categories
  static Future<List<String>> getGiftCategories() async {
    try {
      final snapshot = await _giftsCollection.get();
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] as String? ?? 'Uncategorized';
          })
          .toSet()
          .toList();
      return categories;
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return ['Lucky']; // Default fallback
    }
  }
}
