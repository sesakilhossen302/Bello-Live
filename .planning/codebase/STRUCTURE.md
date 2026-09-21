# Codebase Structure

**Analysis Date:** 2026-09-21

## Directory Layout

```
picture_live/
├── android/                         # Android native module (Kotlin DSL, Gradle configs)
├── assets/                          # Static & animated assets (SVGA, images, icons)
│   ├── animations/                  # Lottie / JSON animation assets
│   ├── icons/                       # SVG and raster application icons
│   ├── images/                      # Static banners, avatars, badges
│   ├── logo/                        # App brand logos
│   └── svga/                        # Vector gift animation files (.svga)
├── ios/                             # iOS native module (Xcode project, Podfile)
├── lib/                             # Main Dart application source code
│   ├── core/                        # Shared application foundation
│   │   ├── config/                  # Runtime endpoints & configuration
│   │   ├── cubits/                  # Global BLoC state managers (AppCubit)
│   │   ├── localization/            # Multi-language string catalogs & delegate
│   │   ├── services/                # Low-level services (LiveKit, Banner cache)
│   │   ├── utils/                   # Formatting, date helpers, converters
│   │   └── widgets/                 # Reusable UI widgets (SVGA player, banners)
│   ├── data/                        # Data sources & repository implementations
│   │   ├── local/                   # Encrypted storage (SecureStorage)
│   │   └── remote/firebase/         # Firebase service modules (RTDB & Firestore)
│   ├── di/                          # Dependency injection container (GetIt)
│   ├── navigation/                  # GoRouter configuration, route paths & bars
│   ├── theme/                       # Color palettes, typography & Material 3 theme
│   ├── ui/                          # Presentation feature screens & components
│   │   ├── agency/                  # Agency management, agent invites & commissions
│   │   ├── apply/                   # Host and agency recruitment forms
│   │   ├── auth/                    # Login, OTP verification & registration
│   │   ├── earnings/                # Reseller balances & transaction histories
│   │   ├── home/                    # Main feed, live streamers tab, party rooms tab
│   │   ├── inbox/                   # Direct messaging & user notifications
│   │   ├── live_streaming/          # Video live streaming & 1v1 PK battle engine
│   │   ├── profile/                 # User profiles, follow graph & wallet
│   │   ├── ranks/                   # Daily/weekly gifter and streamer leaderboards
│   │   ├── store-bag/               # Avatar frames, entrance vehicles & item bag
│   │   ├── streaming/               # Multi-seat audio party rooms (8/16 seats)
│   │   └── widgets/                 # Global overlay widgets (PIP, ban listeners)
│   ├── firebase_options.dart        # Generated Firebase configuration
│   └── main.dart                    # Application bootstrap & top-level overlay stack
├── test/                            # Unit and widget test suites
├── web/                             # Web platform assets
├── analysis_options.yaml            # Dart static analysis configuration
└── pubspec.yaml                     # Project manifest and package dependencies
```

## Directory Purposes

**`lib/core/`:**
- Purpose: Houses application-wide infrastructure, shared state, localization, and media services.
- Contains: Configuration classes, global cubits, language maps, reusable widgets.
- Key files: `lib/core/services/livekit_service.dart`, `lib/core/cubits/app_cubit.dart`, `lib/core/config/app_config.dart`.

**`lib/data/remote/firebase/`:**
- Purpose: Encapsulates all backend interactions with Cloud Firestore, Firebase Realtime Database, Cloud Functions, and Firebase Storage.
- Contains: Static service classes and data mappers.
- Key files: `room_services.dart` (audio rooms), `live_streaming_services.dart` (video & PK), `profile_services.dart` (user data & wallet), `store_service.dart` (inventory).

**`lib/ui/streaming/`:**
- Purpose: Multi-seat interactive audio party room presentation and interaction logic.
- Contains: Page widgets, seat grid layouts, tool bottomsheets, sound effect triggers.
- Key files: `audio_room_page.dart` (primary audio room screen), `bottomsheets/audio_tools_bottomsheet.dart`.

**`lib/ui/live_streaming/`:**
- Purpose: Real-time video broadcasting and split-screen 1v1 PK battle arena.
- Contains: Broadcaster view, audience view, PK progress gauge, interactive bottomsheets.
- Key files: `live_room_page.dart` (primary video screen), `bottomsheets/live_tools_bottomsheet.dart`.

**`lib/navigation/`:**
- Purpose: Declarative navigation structure managing 52 distinct screens with authentication guards.
- Key files: `my_router.dart` (`GoRouter` instance), `routes.dart` (`Routes` enumeration).

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application initialization, DI registration, Firebase boot, and global overlay mounting.
- `lib/navigation/my_router.dart`: Primary route dispatcher handling page push/pop and query argument parsing.

**Configuration:**
- `lib/core/config/app_config.dart`: Runtime RTC endpoints and fallback URLs.
- `lib/firebase_options.dart`: Platform-specific Firebase options (Android, iOS, Web).
- `analysis_options.yaml`: Dart analyzer and linter configuration.
- `pubspec.yaml`: App dependencies, assets, and metadata.

**Core Logic:**
- `lib/core/services/livekit_service.dart`: LiveKit WebRTC state machine and token manager.
- `lib/data/remote/firebase/room_services.dart`: Realtime seat reservation, lock states, and RTDB presence.
- `lib/data/remote/firebase/live_streaming_services.dart`: PK battle matchmaking and video signaling.
- `lib/core/cubits/app_cubit.dart`: Global app state for PIP, locale, and version check.

**Testing:**
- `test/widget_test.dart`: Default Flutter smoke test (currently commented out).

## Naming Conventions

**Files:**
- Lowercase snake_case: `audio_room_page.dart`, `livekit_service.dart`, `room_services.dart`.
- Suffix indicates role: `_page.dart` (screens), `_bottomsheet.dart` (modals), `_service.dart` (APIs), `_cubit.dart` (BLoC), `_state.dart` (state definitions).

**Directories:**
- Lowercase snake_case: `live_streaming/`, `profile_visitors/`, `host_page/`.
- Hyphenated for compound feature names: `store-bag/`.

**Classes & Types:**
- PascalCase: `AudioRoomPage`, `LiveKitService`, `AppCubit`, `MyRouter`.

**Variables & Functions:**
- Lower camelCase: `currentRoomName`, `fetchToken()`, `setMicrophoneEnabled()`.

## Where to Add New Code

**New Feature Screen:**
1. Create new feature directory in `lib/ui/<feature_name>/`.
2. Add screen widget: `lib/ui/<feature_name>/<feature_name>_page.dart`.
3. Declare route enum value in `lib/navigation/routes.dart`.
4. Register `GoRoute` in `lib/navigation/my_router.dart`.

**New Backend / Data Service:**
1. Implement service in `lib/data/remote/firebase/<service_name>_service.dart`.
2. Encapsulate Firestore queries or RTDB references inside typed methods.

**New Shared Component:**
- Place in `lib/core/widgets/` if shared across multiple features.
- Place in `lib/ui/widgets/` if it's a global overlay component or screen listener.

**New Tests:**
- Add unit or widget tests into `test/<feature_name>_test.dart`.

## Special Directories

**`assets/svga/`:**
- Purpose: High-performance vector animation files for virtual gifts, entrance effects, and soundwave rings.
- Generated: No (committed source assets).
- Committed: Yes.

**`android/` & `ios/`:**
- Purpose: Platform-specific native builds and platform channels.
- Generated: Initialized by Flutter, modified with native permissions.
- Committed: Yes.

---

*Structure analysis: 2026-09-21*
