import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreItemModel {
  final String id;
  final String name;
  final String imageUrl;
  final int price;
  final String category;
  final DateTime? expiresAt;

  const StoreItemModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.category,
    this.expiresAt,
  });

  factory StoreItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawPrice = data['price'] ?? data['value'] ?? 0;
    final parsedPrice = rawPrice is num ? rawPrice.toInt() : int.tryParse(rawPrice.toString()) ?? 0;

    return StoreItemModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      imageUrl: data['imageURL'] ?? '',
      price: parsedPrice,
      category: data['category'] ?? 'Uncategorized',
      expiresAt: data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
    );
  }
}

class StoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static final _storeCollection = _firestore.collection('store');
  static final _usersCollection = _firestore.collection('users');

  /// Fetches all store items dynamically grouped by category, ignoring 'Official'
  static Future<Map<String, List<StoreItemModel>>> fetchStoreItems() async {
    final snapshot = await _storeCollection.get();
    final Map<String, List<StoreItemModel>> categorizedItems = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final category = data['category']?.toString() ?? 'Uncategorized';

      // Ignore any category containing "Official"
      if (category.contains('Official')) continue;

      final item = StoreItemModel.fromFirestore(doc);

      // Dynamically add the category if it doesn't exist, then add the item
      categorizedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return categorizedItems;
  }

  /// Purchases an item: deducts balance, adds to bag, and extends expiration if already owned.
  static Future<void> buyItem(StoreItemModel item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final userRef = _usersCollection.doc(uid);
    final bagRef = userRef.collection('bag').doc(item.id);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception("User not found");

      final userData = userDoc.data() ?? {};
      final currentBalance = userData['balance'] ?? 0;
      if (currentBalance < item.price) {
        throw Exception("Insufficient diamonds to purchase this item.");
      }

      final bagDoc = await transaction.get(bagRef);
      DateTime newExpirationDate;

      if (bagDoc.exists) {
        final bagData = bagDoc.data();
        final currentExpTimestamp = bagData?['expiresAt'] as Timestamp?;

        if (currentExpTimestamp != null && currentExpTimestamp.toDate().isAfter(DateTime.now())) {
          newExpirationDate = currentExpTimestamp.toDate().add(const Duration(days: 30));
        } else {
          newExpirationDate = DateTime.now().add(const Duration(days: 30));
        }
      } else {
        newExpirationDate = DateTime.now().add(const Duration(days: 30));
      }

      final Map<String, dynamic> userUpdates = {'balance': FieldValue.increment(-item.price)};

      // Check if this specific item is the active one in its category
      final activeAddOns = userData['activeAddOns'] as Map<String, dynamic>? ?? {};
      final currentCategoryActive = activeAddOns[item.category] as Map<String, dynamic>?;

      if (currentCategoryActive != null && currentCategoryActive['imageUrl'] == item.imageUrl) {
        // Extend the expiry date inside the specific category map
        userUpdates['activeAddOns.${item.category}.expiresAt'] = Timestamp.fromDate(newExpirationDate);
      }

      transaction.update(userRef, userUpdates);

      transaction.set(bagRef, {
        'id': item.id,
        'name': item.name,
        'imageURL': item.imageUrl,
        'value': item.price,
        'category': item.category,
        'lastPurchasedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(newExpirationDate),
      }, SetOptions(merge: true));
    });
  }

  /// Toggles an item as active or inactive FOR ITS SPECIFIC CATEGORY
  static Future<void> toggleActiveItem(StoreItemModel item, bool equip) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    if (equip) {
      // Set this item as the active one for this specific category
      await _usersCollection.doc(uid).update({
        'activeAddOns.${item.category}': {
          'imageUrl': item.imageUrl,
          'expiresAt': item.expiresAt != null ? Timestamp.fromDate(item.expiresAt!) : null,
        },
      });
    } else {
      // Remove the active item for this category
      await _usersCollection.doc(uid).update({'activeAddOns.${item.category}': FieldValue.delete()});
    }
  }

  /// Fetches the user's purchased items dynamically grouped by category
  static Future<Map<String, List<StoreItemModel>>> fetchMyBagItems() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final snapshot = await _usersCollection
        .doc(uid)
        .collection('bag')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .get();

    final Map<String, List<StoreItemModel>> categorizedItems = {};

    for (var doc in snapshot.docs) {
      final item = StoreItemModel.fromFirestore(doc);
      categorizedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return categorizedItems;
  }

  /// Listens to all active items and returns a Map of Category -> Image URL
  static Stream<Map<String, String>> getActiveAddOnsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value({});

    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};

      final data = snapshot.data()!;
      final addOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};

      Map<String, String> activeItems = {};
      final now = DateTime.now();

      // Only return items that haven't expired
      addOns.forEach((category, itemData) {
        final expiry = itemData['expiresAt'] as Timestamp?;
        final url = itemData['imageUrl'] as String?;

        if (url != null && (expiry == null || expiry.toDate().isAfter(now))) {
          activeItems[category] = url;
        }
      });

      return activeItems;
    });
  }
}
