import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class VipService {
  static final Map<String, String?> _vipCache = {};

  /// Synchronously returns cached VIP type ('vvip' | 'vip' | null) if known.
  static String? getVipTypeSync(String userId) => _vipCache[userId];

  /// Sets cached VIP type directly.
  static void setVipType(String userId, String? vipType) {
    if (vipType != null && vipType.isNotEmpty) {
      _vipCache[userId] = vipType.toLowerCase();
    }
  }

  /// Asynchronously resolves whether a user is VVIP, VIP, or normal.
  static Future<String?> getVipType(String userId) async {
    if (userId.isEmpty) return null;
    if (_vipCache.containsKey(userId)) return _vipCache[userId];

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        _vipCache[userId] = null;
        return null;
      }

      final data = doc.data()!;
      final result = resolveVipTypeFromUserData(data);
      _vipCache[userId] = result;
      return result;
    } catch (e) {
      debugPrint("Error fetching VIP status for $userId: $e");
      return null;
    }
  }

  /// Parses user document fields to determine VIP / VVIP status.
  static String? resolveVipTypeFromUserData(Map<String, dynamic> data) {
    // 1. Direct flags
    if (data['isVvip'] == true) return 'vvip';
    if (data['isVip'] == true) return 'vip';

    // 2. Direct string / package fields
    final String vipStr = (data['vip'] ?? data['vipType'] ?? '').toString().toLowerCase();
    if (vipStr.contains('vvip')) return 'vvip';
    if (vipStr.contains('vip')) return 'vip';

    final String pkgStr = (data['activePackage'] ?? data['package'] ?? '').toString().toLowerCase();
    if (pkgStr.contains('vvip') || pkgStr.contains('royal') || pkgStr.contains('king')) {
      return 'vvip';
    }
    if (pkgStr.contains('vip') || pkgStr.contains('queen') || pkgStr.contains('crown')) {
      return 'vip';
    }

    // 3. activeAddOns
    if (data.containsKey('activeAddOns')) {
      final addOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();
      for (final entry in addOns.entries) {
        final key = entry.key.toLowerCase().trim();
        final itemData = entry.value as Map<String, dynamic>?;
        if (itemData != null) {
          final expiry = itemData['expiresAt'] as Timestamp?;
          final isNotExpired = expiry == null || expiry.toDate().isAfter(now);
          if (isNotExpired) {
            final name = (itemData['name'] ?? itemData['title'] ?? '').toString().toLowerCase();
            final fullStr = '$key $name';
            if (fullStr.contains('vvip') || fullStr.contains('royal') || fullStr.contains('king')) {
              return 'vvip';
            }
            if (fullStr.contains('vip') || fullStr.contains('queen') || fullStr.contains('crown')) {
              return 'vip';
            }
          }
        }
      }
    }

    return null;
  }
}
