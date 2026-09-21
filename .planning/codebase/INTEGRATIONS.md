# External Integrations

**Analysis Date:** 2026-09-21

## APIs & External Services

**Real-Time Communications (RTC):**
- LiveKit SFU - WebRTC media server handling audio rooms, video streams, dynamic bitrates, and data messages
  - SDK/Client: `livekit_client: ^2.2.8`, `flutter_webrtc: ^1.2.1` (`lib/core/services/livekit_service.dart`)
  - Connection Endpoint: `ws://129.212.226.12:7880` (configured via `lib/core/config/app_config.dart` or Firestore remote config)
- RTC Token Plane (`rtc_server`) - Node.js / TypeScript microservice issuing signed JWT tokens with granular room permissions
  - Endpoint: `http://129.212.226.12:5000/api/token`
  - Implementation: `fetchToken()` in `lib/core/services/livekit_service.dart`

**Push Notifications:**
- Firebase Cloud Messaging (FCM) - Background notifications and host event alerts
  - SDK/Client: `firebase_messaging: ^16.1.3`, `flutter_local_notifications: ^20.1.0`
  - Implementation: `lib/data/remote/firebase/notification_service.dart`
  - Topics: Subscribes to host notifications via `host_{hostUid}`

**Third-Party Media:**
- YouTube Audio/Video Streaming - Media playback within rooms
  - SDK/Client: `youtube_player_flutter: ^10.0.1`, `youtube_explode_dart: ^3.1.0`

## Data Storage

**Databases:**
- Cloud Firestore (Persistent Data Plane):
  - Client: `cloud_firestore: ^6.0.2`
  - Collections:
    - `users`: User profiles, coin/diamond balances, VIP level, bans
    - `users/{uid}/bag`: Purchased virtual cosmetic items (frames, vehicles, skins)
    - `store`: Catalog of purchasable virtual goods and packages
    - `reseller_transactions`: Permanent audit log of coin seller transfers
    - `appSettings`: App configuration, dynamic RTC endpoints (`appSettings/zego_config`), version control (`appSettings/app_version`)
    - `userLevels`: XP thresholds for diamond-based leveling system
    - `banned_devices` & `banned_emails`: Global moderation lists
- Firebase Realtime Database (RTDB) (Ephemeral Signaling Plane):
  - Client: `firebase_database: ^12.1.0`
  - Nodes:
    - `/rooms`: Active room metadata, host information, locked status, background skins
    - `/room_participants`: Seat allocation (seats 0-15), mute state, co-host flags, room coins
    - `/room_events`: Overwritten real-time gift and emoji bursts
    - `/room_requests`: Speaker seat requests and PK battle challenge states
    - `/.info/connected`: Client connection state for `onDisconnect` seat teardown

**File Storage:**
- Firebase Cloud Storage:
  - Client: `firebase_storage: ^13.0.4`
  - Implementation: `lib/data/remote/firebase/media_services.dart`
  - Usage: User profile pictures, room backgrounds, custom SVGA files, chat media

**Caching:**
- Encrypted Secure Storage:
  - Client: `flutter_secure_storage: ^9.2.4` (`lib/data/local/secure_storage/secure_storage.dart`)
  - Usage: User auth credentials, active user profile JSON, selected language locale
- Image Cache:
  - Client: `cached_network_image: ^3.4.1`

## Authentication & Identity

**Auth Provider:**
- Firebase Auth & Google Sign-In:
  - Implementation: `lib/ui/auth/login/login_cubit.dart`
  - Providers: Google OAuth (`google_sign_in: ^7.2.0`), Phone OTP (`pin_code_fields: ^8.0.1`), Email/Password
  - Session Persistence: Handled via `FirebaseAuth.instance.authStateChanges()` in `lib/main.dart`

## Monitoring & Observability

**Error Tracking:**
- Standard Flutter debug logging via `debugPrint`
- No third-party APM SDK (Sentry or Firebase Crashlytics) currently installed in `pubspec.yaml`

**Logs:**
- Console-based debug output across services:
  - LiveKit connection logs: `[LiveKitService]` prefix in `lib/core/services/livekit_service.dart`
  - Configuration logs: `[AppConfig]` prefix in `lib/core/config/app_config.dart`

## CI/CD & Deployment

**Hosting:**
- Self-hosted LiveKit SFU and Node.js token server on Ubuntu VPS (`129.212.226.12`)
- Firebase managed backend (Firestore, RTDB, Auth, Storage, Functions)

**CI Pipeline:**
- Local Flutter build toolchain (`flutter build apk`, `flutter build appbundle`)
- No active GitHub Actions or GitLab CI workflows detected in `.github/`

## Environment Configuration

**Required Configurations:**
- Firebase platform options in `lib/firebase_options.dart`
- Android manifest permissions in `android/app/src/main/AndroidManifest.xml` (Microphone, Camera, Bluetooth, Internet)
- Firestore document `appSettings/zego_config` containing `livekitUrl` and `tokenServerUrl`

**Secrets location:**
- Native Android `google-services.json` and iOS `GoogleService-Info.plist` (configured per platform)
- No plain `.env` files with API keys committed in source tree

## Webhooks & Callbacks

**Incoming:**
- FCM push notification payloads processed in background via `NotificationService.initialize()` (`lib/data/remote/firebase/notification_service.dart`)
- LiveKit WebRTC data packet callbacks (`dataMessagesStream` in `lib/core/services/livekit_service.dart`)

**Outgoing:**
- HTTP POST request to `$tokenServerUrl/token` when joining or hosting a live room (`lib/core/services/livekit_service.dart`)

---

*Integration audit: 2026-09-21*
