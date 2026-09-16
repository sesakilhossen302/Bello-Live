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
  final String subCategory;

  GiftModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.iconUrl,
    required this.value,
    required this.category,
    this.subCategory = '',
  });

  factory GiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GiftModel(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageURL'] ?? '',
      iconUrl: data['iconURL'] ?? '',
      value: data['value'] ?? data['price'] ?? 0,
      category: data['category'] ?? 'Uncategorized',
      subCategory: data['subCategory'] ?? data['subcategory'] ?? '',
    );
  }
}

class AssetsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _storeCollection = _firestore.collection('store');
  static final CollectionReference _giftsCollection = _firestore.collection('store');

  // Stream of Emojis from Firestore
  static Stream<List<EmojiModel>> getEmojis() {
    return _storeCollection
        .where('category', isEqualTo: 'Emoji')
        .where('tier', isEqualTo: 'free')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EmojiModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Stream of Gifts from Firestore
  static Stream<List<GiftModel>> getGifts() {
    return _giftsCollection.where('isActive', isEqualTo: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Get gifts by category
  static Stream<List<GiftModel>> getGiftsByCategory(String category) {
    return _giftsCollection
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();
    });
  }

  // NEW: Get gifts by subCategory (safely filters locally to avoid index issues)
  static Stream<List<GiftModel>> getGiftsBySubCategory(String subCategory) {
    return _giftsCollection
        .where('category', isEqualTo: 'Gift')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final allGifts = snapshot.docs.map((doc) => GiftModel.fromFirestore(doc)).toList();
      if (subCategory == 'Gift' || subCategory == 'All' || subCategory.isEmpty) {
        return allGifts;
      }
      return allGifts.where((g) => g.subCategory == subCategory).toList();
    });
  }

  // NEW: Get all unique gift categories
  static Future<List<String>> getGiftSubCategories() async {
    try {
      final snapshot = await _giftsCollection
          .where('category', isEqualTo: 'Gift')
          .where('isActive', isEqualTo: true)
          .get();
      final subCategories = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['subCategory'] as String? ?? data['subcategory'] as String? ?? '';
          })
          .where((subCat) => subCat.isNotEmpty && subCat.toLowerCase() != 'gift')
          .toSet()
          .toList();
      return subCategories;
    } catch (e) {
      debugPrint('Error fetching subcategories: $e');
      return [];
    }
  }
}
