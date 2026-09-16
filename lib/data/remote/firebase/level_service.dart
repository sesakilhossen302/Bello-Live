import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LevelService {
  static final _firestore = FirebaseFirestore.instance;
  
  // Sorted descending by diamondsRequired
  static List<Map<String, dynamic>> _userLevels = [];
  
  static Future<void> init() async {
    try {
      final snapshot = await _firestore.collection('userLevels').get();
      _userLevels = snapshot.docs.map((doc) => doc.data()).toList();
      _userLevels.sort((a, b) => (b['diamondsRequired'] as num).compareTo(a['diamondsRequired'] as num));
    } catch (e) {
      debugPrint("Error fetching userLevels: $e");
    }
  }
  
  static int getSentLevel(int totalSent) {
    if (totalSent < 0) return 0;
    
    // Default fallback if Firestore fails or is empty
    if (_userLevels.isEmpty) {
      const List<int> thresholds = [
        50000, 150000, 300000, 500000, 1000000, 2000000, 4000000, 6000000, 10000000, 15000000,
        20000000, 25000000, 35000000, 50000000, 80000000, 110000000, 140000000, 170000000, 205000000, 240000000
      ];
      for (int i = thresholds.length - 1; i >= 0; i--) {
        if (totalSent >= thresholds[i]) {
          return i + 1;
        }
      }
      return 0;
    }

    for (final config in _userLevels) {
      final required = (config['diamondsRequired'] ?? 0) as num;
      if (totalSent >= required) {
        return (config['level'] ?? 0) as int;
      }
    }
    
    return 0; // Default level if less than the lowest threshold
  }
  
  static int getRequiredXP(int level) {
    if (level <= 0) return 0;
    
    if (_userLevels.isEmpty) {
      const List<int> thresholds = [
        50000, 150000, 300000, 500000, 1000000, 2000000, 4000000, 6000000, 10000000, 15000000,
        20000000, 25000000, 35000000, 50000000, 80000000, 110000000, 140000000, 170000000, 205000000, 240000000
      ];
      if (level > thresholds.length) return thresholds.last;
      return thresholds[level - 1];
    }

    final config = _userLevels.firstWhere(
      (c) => (c['level'] as num?)?.toInt() == level, 
      orElse: () => <String, dynamic>{}
    );
    
    if (config.isNotEmpty) {
      return (config['diamondsRequired'] as num?)?.toInt() ?? 0;
    }
    
    // Fallback: return the highest required if level is higher than max defined
    if (_userLevels.isNotEmpty && level > (_userLevels.first['level'] as num?)!.toInt()) {
      return (_userLevels.first['diamondsRequired'] as num?)?.toInt() ?? 0;
    }
    
    return 0;
  }
}
