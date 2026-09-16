import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class GlobalGiftBannerService {
  static final DatabaseReference _globalBannersRef =
      FirebaseDatabase.instance.ref('global_gift_banners');
  static final DatabaseReference _latestBannerRef =
      FirebaseDatabase.instance.ref('global_latest_gift');

  /// Broadcasts a gift event across the entire app in real time so all connected users see the banner.
  static Future<void> broadcastGift({
    required String senderId,
    required String senderName,
    String? senderPicture,
    required String receiverName,
    String? receiverId,
    required int giftValue,
    String? giftImageUrl,
    String? roomId,
    String? roomType, // 'liveStream' or 'audioRoom'
  }) async {
    try {
      final newRef = _globalBannersRef.push();
      final bannerData = {
        'id': newRef.key,
        'senderId': senderId,
        'senderName': senderName.isNotEmpty ? senderName : 'User',
        'senderPicture': senderPicture ?? '',
        'receiverName': receiverName.isNotEmpty ? receiverName : 'Host',
        'receiverId': receiverId ?? '',
        'giftValue': giftValue,
        'giftImageUrl': giftImageUrl ?? '',
        'roomId': roomId ?? '',
        'roomType': roomType ?? 'liveStream',
        'timestamp': ServerValue.timestamp,
      };
      await newRef.set(bannerData);
      await _latestBannerRef.set(bannerData);
      debugPrint('🎁 Broadcasted global gift banner: $bannerData');
    } catch (e) {
      debugPrint('Error broadcasting global gift banner: $e');
    }
  }

  static Query getGlobalBannersQuery() {
    return _globalBannersRef.limitToLast(10);
  }

  static DatabaseReference getLatestBannerRef() {
    return _latestBannerRef;
  }
}
