import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/app_config.dart';

class AppServices {
  static final _firestore = FirebaseFirestore.instance;

  // Collection Reference
  static final _appSettingsCollection = _firestore.collection('appSettings');

  // The specific document ID where LiveKit server settings are stored
  static const String _liveKitDocId = 'livekit_config';

  /// Fetches LiveKit SFU URL and Token Server URL dynamically from Firestore,
  /// with automatic fallback to AppConfig defaults.
  static Future<Map<String, String>> getLiveKitConfig() async {
    try {
      final doc = await _appSettingsCollection.doc(_liveKitDocId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final liveKitUrl = (data['liveKitUrl'] as String?) ?? AppConfig.defaultLiveKitUrl;
        final tokenServerUrl = (data['tokenServerUrl'] as String?) ?? AppConfig.defaultTokenServerUrl;

        AppConfig.updateEndpoints(livekit: liveKitUrl, tokenServer: tokenServerUrl);

        return {
          'liveKitUrl': liveKitUrl,
          'tokenServerUrl': tokenServerUrl,
        };
      }
    } catch (e) {
      debugPrint('[AppServices] Error fetching LiveKit config from Firestore: $e');
    }

    // Fallback to configured defaults
    return {
      'liveKitUrl': AppConfig.liveKitUrl,
      'tokenServerUrl': AppConfig.tokenServerUrl,
    };
  }
}
