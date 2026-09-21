# Technology Stack

**Analysis Date:** 2026-09-21

## Languages

**Primary:**
- Dart ^3.9.0 - Entire application frontend, state machines, and services (`lib/`)

**Secondary:**
- Kotlin / Java - Android native integration, audio hardware lifecycle, and foreground services (`android/`)
- Swift / Objective-C - iOS native platform layer, AVFoundation audio routing (`ios/`)
- Python - One-off utility and migration scripts (`script.py`, `replace_print.py`)

## Runtime

**Environment:**
- Flutter SDK ^3.9.0
- Dart SDK ^3.9.0

**Package Manager:**
- Flutter Pub (`pubspec.yaml`)
- Lockfile: present (`pubspec.lock`)

## Frameworks

**Core:**
- Flutter (Material Design 3 enabled) - Mobile application framework (`pubspec.yaml`, `lib/main.dart`)
- LiveKit WebRTC (`livekit_client: ^2.2.8`, `flutter_webrtc: ^1.2.1`) - Real-Time communications engine for audio party rooms and video broadcasts (`lib/core/services/livekit_service.dart`)
- Firebase (`firebase_core: ^4.1.1`) - Cloud backend and infrastructure

**State Management & DI:**
- `flutter_bloc: ^9.1.1` / `bloc: ^9.2.0` - Unidirectional application-wide state management (`lib/core/cubits/app_cubit.dart`)
- `get_it: ^8.2.0` - Service locator dependency injection (`lib/di/get_it.dart`)
- `rxdart: ^0.28.0` - Reactive stream composition for real-time signaling (`lib/core/services/livekit_service.dart`)
- `get: ^4.6.6` - Utility helpers (`pubspec.yaml`)

**Routing:**
- `go_router: ^16.2.1` - Declarative routing engine with 52 registered routes (`lib/navigation/my_router.dart`, `lib/navigation/routes.dart`)

**Testing:**
- `flutter_test` (Flutter SDK) - Unit and widget testing suite (`pubspec.yaml`, `test/widget_test.dart`)

**Build/Dev:**
- `flutter_lints: ^5.0.0` - Static lint rules (`analysis_options.yaml`)
- `flutter_launcher_icons: ^0.14.4` - Automated app icon generator (`pubspec.yaml`)
- `change_app_package_name: ^1.5.0` - Application identifier tooling (`pubspec.yaml`)

## Key Dependencies

**Critical:**
- `livekit_client: ^2.2.8` - LiveKit WebRTC client for room connections, audio/video track publishing, and data messaging (`lib/core/services/livekit_service.dart`)
- `flutter_webrtc: ^1.2.1` - Hardware WebRTC video renderers and track pipelines (`lib/core/services/livekit_service.dart`)
- `firebase_database: ^12.1.0` - Ultra-low-latency real-time signaling for seats, events, and PK battles (`lib/data/remote/firebase/room_services.dart`)
- `cloud_firestore: ^6.0.2` - Persistent document storage for users, transactions, and store inventory (`lib/data/remote/firebase/profile_services.dart`)
- `firebase_auth: ^6.1.0` & `google_sign_in: ^7.2.0` - User identity and Google authentication (`lib/ui/auth/login/login_cubit.dart`)
- `flutter_svga: ^0.0.6` - Hardware-accelerated vector animation player for virtual gifts (`lib/core/widgets/svga_player.dart`)

**Infrastructure:**
- `flutter_secure_storage: ^9.2.4` - Encrypted key-value persistence for auth tokens and locale (`lib/data/local/secure_storage/secure_storage.dart`)
- `firebase_messaging: ^16.1.3` & `flutter_local_notifications: ^20.1.0` - Cloud and local push notifications (`lib/data/remote/firebase/notification_service.dart`)
- `flutter_udid: ^4.1.6` & `device_info_plus: ^11.5.0` - Device fingerprinting for anti-fraud and hardware bans (`lib/ui/widgets/global_device_ban_listener.dart`)
- `audioplayers: ^6.6.0` - In-room music playback and gift sound effects (`lib/ui/streaming/bottomsheets/play_music_bottomsheet.dart`)
- `cached_network_image: ^3.4.1` - In-memory and disk image caching (`pubspec.yaml`)
- `video_player: ^2.10.1` & `record: ^6.1.2` - Video playback and microphone recording

## Configuration

**Environment:**
- Firebase platform options configured in `lib/firebase_options.dart` and `firebase.json`
- LiveKit & RTC control plane endpoints loaded from `appSettings/zego_config` in Firestore with fallback in `lib/core/config/app_config.dart`
- Active LiveKit SFU: `ws://129.212.226.12:7880`
- Active Token Server: `http://129.212.226.12:5000/api`

**Build:**
- `analysis_options.yaml`: Enforces `package:flutter_lints/flutter.yaml`
- `android/app/build.gradle.kts`: Configured for `minSdk 21`, `targetSdk 34`, MultiDex, and Core Library Desugaring

## Platform Requirements

**Development:**
- Flutter SDK `^3.9.0` with Dart `^3.9.0`
- Android SDK 34 / Java 17+
- macOS / Xcode 15+ for iOS compilation

**Production:**
- Android: `minSdk 21`, `targetSdk 34` (`android/app/build.gradle.kts`)
- iOS: iOS 12.0+

---

*Stack analysis: 2026-09-21*
