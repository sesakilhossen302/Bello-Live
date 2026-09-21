<!-- refreshed: 2026-09-21 -->
# Architecture

**Analysis Date:** 2026-09-21

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             PRESENTATION LAYER                              │
│  - Live Rooms: AudioRoomPage (Audio), LiveRoomPage (Video & PK)             │
│  - Global Overlays: FloatingMinimizedRoom (PIP), GlobalGiftBanner, BanCheck │
│  - Features: Store, Bag, Reseller Hub, Host Management, Rankings, Profile   │
│  - Renderers: VideoTrackRenderer (WebRTC), SVGAEasyPlayer (Animations)      │
│  - File Locations: `lib/ui/`, `lib/core/widgets/`                           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          APPLICATION STATE LAYER                            │
│  - Global Cubit: AppCubit / AppState (Minimized room, locale, force update) │
│  - Dependency Injection: GetIt Service Locator (`lib/di/get_it.dart`)       │
│  - Reactive Pipelines: Dart StreamControllers & RxDart Subjects             │
│  - Routing: GoRouter with 52 routes (`lib/navigation/my_router.dart`)        │
└──────────────────────┬───────────────────────────────┬──────────────────────┘
                       │                               │
                       ▼                               ▼
┌──────────────────────────────────────┐  ┌───────────────────────────────────┐
│       COMMUNICATION / RTC PLANE      │  │        DATA & STORAGE LAYER       │
│  - LiveKit WebRTC SFU Mesh           │  │  - Firebase Realtime Database:    │
│    (`lib/core/services/livekit_...`) │  │    Ephemeral seats, mic status,   │
│  - Primary Room & Opponent PK Room   │  │    gift bursts, participant state │
│  - Audio DSP, VAD & Speaker Monitor  │  │  - Cloud Firestore:               │
│  - Token Plane (`rtc_server` / JWT)  │  │    Users, bags, transactions,     │
│  - In-Room Data Messages (Chat/Anim) │  │    app configuration, bans        │
│                                      │  │  - Local: FlutterSecureStorage    │
└──────────────────────────────────────┘  └───────────────────────────────────┘
```

## Architecture Layers

**Presentation Layer:**
- Live streaming views: `lib/ui/streaming/audio_room_page.dart` (multi-seat party room) and `lib/ui/live_streaming/live_room_page.dart` (video broadcasting and PK split-screen)
- Global persistent overlay stack in `MaterialApp.builder` (`lib/main.dart`):
  - `FloatingMinimizedRoom`: Picture-in-Picture audio/video floating player (`lib/ui/widgets/floating_minimized_room.dart`)
  - `GlobalGiftBanner`: High-value gift broadcast ticker across screens (`lib/ui/widgets/global_gift_banner.dart`)
  - `GlobalDeviceBanListener`: Hardware UDID ban interceptor (`lib/ui/widgets/global_device_ban_listener.dart`)
  - `UserBlockListener`: Account suspension monitor (`lib/ui/widgets/user_block_listener.dart`)
  - `ForceUpdateScreen`: Semver version gate (`lib/ui/widgets/force_update_screen.dart`)
- Feature modules: Reseller Hub (`lib/ui/earnings/`), Store/Bag (`lib/ui/store-bag/`), Agency (`lib/ui/agency/`), User Profile (`lib/ui/profile/`)

**Application State Layer:**
- `AppCubit` & `AppState` (`lib/core/cubits/app_cubit.dart`): Manages minimized room state, active locale, and app version checks
- Service Locator (`lib/di/get_it.dart`): Registers global singletons (`SecureStorage`, `AppCubit`)
- Declarative Navigation (`lib/navigation/my_router.dart`): Configures 52 discrete routes with URL routing and query parameters

**Communication / RTC Plane:**
- `LiveKitService` (`lib/core/services/livekit_service.dart`): Core WebRTC client
  - Dual-room connection handling: Primary `_room` for participant broadcast; `_opponentRoom` for 1v1 PK battles
  - Track management: Local audio/video publishing, speakerphone/earpiece switching, hardware camera flips
  - Reactive streams: `activeSpeakersStream`, `dataMessagesStream`, `chatMessagesStream`, `connectionStateStream`
  - Token authentication: Requests signed JWTs from `rtc_server` using `AppServices.getLiveKitConfig()`

**Data & Storage Layer:**
- Dual-Database architecture separating high-frequency ephemeral state from durable transacted records:
  - **Firebase Realtime Database (RTDB)**: Low-latency signalling for `/rooms`, `/room_participants` (seats 0-15), `/room_events` (gifts), and `/room_requests`
  - **Cloud Firestore**: ACID transactions for diamond/coin transfers, user catalog, store bag, agency tiers, and level definitions
  - **Flutter Secure Storage**: Encrypted device keystore for tokens and language choices (`lib/data/local/secure_storage/secure_storage.dart`)

## Data Flow

**1. Audio Room Participation & Seat Muting Flow:**
1. User enters room: `AudioRoomPage` fetches LiveKit token via `LiveKitService.instance.fetchToken()`.
2. Client connects to LiveKit SFU via `LiveKitService.instance.connectRoom()`.
3. RTDB listener in `AudioRoomPage` receives participant updates from `/room_participants/{roomId}`.
4. If participant is granted speaker permissions or assigned to seat, `LiveKitService.instance.setMicrophoneEnabled(true)` unmutes native track.
5. `LiveKitService.instance.activeSpeakersStream` triggers SVGA speaking soundwave rings around the active participant avatar.

**2. 1v1 PK Cross-Room Battle Flow:**
1. Host initiates challenge via `LiveStreamService.sendPKInvite()`.
2. Opponent accepts, updating `pkState` in `/rooms/{roomId}/pkState`.
3. Both hosts invoke `LiveKitService.instance.connectOpponentPKRoom(opponentRoomId)`.
4. UI splits into dual viewports rendering local `VideoTrackRenderer` and remote `VideoTrackRenderer`.
5. Real-time scores dynamically update from `/room_events/{roomId}/gift` during the battle window.

**3. In-App Picture-in-Picture (PIP) Flow:**
1. User taps minimize button on `AudioRoomPage` or `LiveRoomPage`.
2. Page pops from navigator; `AppCubit.minimizeRoom()` updates global `AppState`.
3. `FloatingMinimizedRoom` mounted in `MaterialApp.builder` renders floating draggable widget.
4. Real-time audio stream remains active through persistent `LiveKitService.instance.room`.
5. Tapping floating window re-pushes route into navigation stack.

## Key Abstractions

**`LiveKitService`:**
- Purpose: Singleton orchestrating all WebRTC media streams, token exchange, and RTC data messages
- Location: `lib/core/services/livekit_service.dart`
- Pattern: Singleton with broadcast `StreamController`s and dual-`Room` state machine

**`RoomService`:**
- Purpose: Manages audio party room lifecycle, seat allocations, lock states, and participant RTDB presence
- Location: `lib/data/remote/firebase/room_services.dart`
- Pattern: Service class interacting with `FirebaseDatabase.instance`

**`LiveStreamService`:**
- Purpose: Video room lifecycle, 1v1 PK battle coordination, and matchmaking
- Location: `lib/data/remote/firebase/live_streaming_services.dart`
- Pattern: Service class interfacing with Firestore and RTDB

**`AppCubit` & `AppState`:**
- Purpose: Global application state (PIP state, locale, versioning)
- Location: `lib/core/cubits/app_cubit.dart`, `lib/core/cubits/app_state.dart`
- Pattern: BLoC / Cubit unidirectional state management

## Entry Points

**`lib/main.dart` (`main()`):**
- Triggers: Application boot on mobile device
- Responsibilities: Initializes bindings, registers DI (`registerDI()`), connects Firebase (`Firebase.initializeApp()`), prefetches RTC configs (`AppServices.getLiveKitConfig()`), caches banners (`HomeBannerCacheService.init()`), and boots `MyApp` with `MaterialApp.router`.

**`lib/navigation/my_router.dart` (`MyRouter.router`):**
- Triggers: Route changes, deep links, push notifications
- Responsibilities: Parses route paths, verifies authentication state, and maps URL paths to feature pages.

## Architectural Constraints

- **Threading:** Flutter single-threaded event loop. Intensive video decoding and WebRTC encoding offloaded to native background threads via `flutter_webrtc`.
- **Global state:** `LiveKitService.instance` (singleton RTC engine), `GetIt.I<AppCubit>()` (global app state), `GetIt.I<SecureStorage>()`.
- **Dual-Database Segregation:** High-frequency seat updates and gift animations MUST use RTDB leaf nodes (`/room_participants/$roomId`, `/room_events/$roomId/gift`). Durable transactions and billing MUST use Cloud Firestore `runTransaction`.
- **Memory Management:** All RTC stream subscriptions and RTDB listeners must be cancelled in widget `dispose()`.

## Anti-Patterns

### Mega-Widgets (God-Classes)

**What happens:** `AudioRoomPage` (`lib/ui/streaming/audio_room_page.dart` - 4,851 lines) and `LiveRoomPage` (`lib/ui/live_streaming/live_room_page.dart` - 4,536 lines) combine UI layout, RTDB listeners, WebRTC lifecycle, animations, and modal state in a single class.
**Why it's wrong:** High risk of regression during minor edits, unmaintainable testing surface, and potential memory leaks if subscriptions are missed.
**Do this instead:** Extract domain concerns into dedicated Cubits (e.g., `AudioRoomCubit`, `PKBattleCubit`) and modular child widgets.

### Unsafe BuildContext Across Async Gaps

**What happens:** 90+ warnings in `dart_analyze_async.txt` show `context.push()`, `Navigator.pop(context)`, or `ScaffoldMessenger.of(context)` called after `await` without `if (!mounted) return;`.
**Why it's wrong:** Causes crashes or state corruption if the user navigates away before an asynchronous Firestore/HTTP network call finishes.
**Do this instead:** Guard every asynchronous boundary with `if (!mounted) return;` prior to referencing `BuildContext`.

## Error Handling

**Strategy:** Defensive `try-catch` blocks wrapping asynchronous network calls with fallback UI alerts.

**Patterns:**
- LiveKit token connection: Wrapped in `try-catch` with error reporting and fallback disconnection (`lib/core/services/livekit_service.dart`)
- Firestore transactions: Atomic abort on insufficient balance or missing docs (`lib/data/remote/firebase/store_service.dart`)

## Cross-Cutting Concerns

**Logging:** Prefixed console logs via `debugPrint` (e.g. `[LiveKitService]`, `[AppConfig]`).
**Validation:** Client-side form validation for auth, numeric checks on coin transactions, semver comparison for version enforcement.
**Authentication:** Firebase Auth state monitored via `FirebaseAuth.instance.authStateChanges()` in `lib/main.dart` with token persistence in `SecureStorage`.

---

*Architecture analysis: 2026-09-21*
