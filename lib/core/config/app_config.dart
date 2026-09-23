import 'package:flutter/foundation.dart';

class AppConfig {
  /// Default LiveKit SFU WebSocket URL (Deployed VPS).
  static String defaultLiveKitUrl = 'ws://167.71.207.84:7880';

  /// Default Node.js / TypeScript RTC Token Control Plane URL (`rtc_server`).
  static String defaultTokenServerUrl = 'http://167.71.207.84:5000/api';

  /// Active runtime endpoints (initialized from Firestore or fallbacks)
  static String liveKitUrl = defaultLiveKitUrl;
  static String tokenServerUrl = defaultTokenServerUrl;
  static String get apiBaseUrl => tokenServerUrl;

  /// Update active runtime endpoints
  static void updateEndpoints({String? livekit, String? tokenServer}) {
    if (livekit != null && livekit.isNotEmpty) {
      liveKitUrl = livekit;
      debugPrint('[AppConfig] LiveKit URL set to: $liveKitUrl');
    }
    if (tokenServer != null && tokenServer.isNotEmpty) {
      tokenServerUrl = tokenServer;
      debugPrint('[AppConfig] Token Server URL set to: $tokenServerUrl');
    }
  }
}
