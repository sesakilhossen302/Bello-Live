# Bello Live (FlowLive) — Enterprise Architecture & System Engineering Manual
### Complete Technical Reference, RTC Communication Engine Analysis & Codebase Memory
**Document Author**: Principal Mobile & WebRTC Systems Architect (20+ Years Experience)  
**Target Audience**: Senior Engineers, Solution Architects, WebRTC Specialists, and Autonomous AI Agents  
**Target Codebase**: `d:\01_Office_Work\Office_Work\FlowLive\FlowLive` (Package: `picture_live`, Android Namespace: `com.sblivebd.app`)  
**Companion Systems**: `rtc_server` (LiveKit Token Plane), `LIVEKIT_ARCHITECTURE_AND_MIGRATION_GUIDE.md`

---

## 1. Executive Summary & Product DNA

**Bello Live** (internally identified as `picture_live` and `FlowLive`) is a carrier-grade, highly interactive live streaming and social entertainment mobile application. Built using the Flutter framework targeting Android (minimum SDK 21, target SDK 34) and iOS, the platform combines low-latency real-time voice and video communications with an expansive virtual gifting economy, agency/reseller infrastructure, and gamified social spaces.

### Primary Operational Domains
1. **Multi-Seat Audio Party Rooms**: 8 to 16 participant voice rooms featuring dynamic seat allocations, host/co-host hierarchies, automated speaker promotions, real-time voice activity detection (VAD), and hardware DSP controls.
2. **Interactive Live Video & 1v1 PK Battles**: Low-latency video broadcasting with split-screen dual-host PK battles, cross-room stream subscriptions, real-time battle progress gauges, and countdown timers.
3. **High-Throughput Virtual Gifting Engine**: SVGA (`flutter_svga`) hardware-rendered visual effects, real-time combo/hit counters, audio cues, and instant diamond-to-coin wallet mutations.
4. **Reseller & Agency Distribution Hub**: Multi-tier monetization supporting authorized coin sellers who transfer balance directly to users via atomic database transactions, with agency management and earnings settlements.
5. **Floating Room (In-App Picture-in-Picture)**: Uninterrupted real-time audio/video playback during app-wide navigation via a globally managed floating PIP widget.
6. **Device-Level Moderation & Anti-Fraud**: Hardware UDID tracking, dynamic device bans, real-time account suspension listeners, and remote force-update enforcement.

---

## 2. High-Level Architecture & Layer Breakdown

The codebase follows a **Feature-Driven Layered Architecture** with unidirectional data flow conventions, strict separation between ephemeral signaling and persistent storage, and dependency inversion via service locators.

```
+---------------------------------------------------------------------------------------+
|                                    PRESENTATION LAYER                                 |
|  - Screens: AudioRoomPage, LiveRoomPage, Store, ResellerHub, Profile, Rankings        |
|  - Floating Overlay: FloatingMinimizedRoom (PIP Widget mounted in MaterialApp.builder)|
|  - BottomSheets: AudioTools, LiveTools, MusicPlayer, Gifts, Participants, PKInvite    |
|  - Engine Renderers: ZegoAudioVideoView, SVGAEasyPlayer, SVGAImage                    |
+-------------------------------------------+-------------------------------------------+
                                            |
                                            v
+---------------------------------------------------------------------------------------+
|                                APPLICATION STATE LAYER                                |
|  - Global State: AppCubit (AppState) via flutter_bloc (Locale, MinimizedRoom, Updates)|
|  - Media Control: MusicPlayerManager (ChangeNotifier)                                 |
|  - Reactive Streams: RxDart & Dart async StreamSubscriptions                          |
|  - Dependency Injection: GetIt Service Locator (get_it.dart)                          |
|  - Route Management: GoRouter (MyRouter & Routes enum with 52 routes)                 |
+---------------------+-------------------------------------+---------------------------+
                      |                                     |
                      v                                     v
+-----------------------------------+     +---------------------------------------------+
|    COMMUNICATION / RTC PLANE      |     |               DATA & STORAGE LAYER          |
|  - Primary: ZEGOCLOUD             |     |  1. Firebase Realtime Database (RTDB):      |
|    * zego_uikit (v2.28.28)        |     |     - /rooms (Static config & skins)        |
|    * zego_express_engine (v3.23.0)|     |     - /room_participants (Seat state, mic)  |
|    * zego_uikit_prebuilt_audio    |     |     - /room_events (Transient gifts/emojis) |
|  - Cross-Room Stream Relay (PK)   |     |     - /room_requests (Speaker/co-host/PK)   |
|  - In-Room Message Data Channel   |     |  2. Cloud Firestore:                        |
|  - Audio DSP & Hardware Routing   |     |     - users, store, reseller_transactions   |
|  - Planned: LiveKit SFU           |     |     - appSettings/zego_config, userLevels   |
|    (See rtc_server / Migration)   |     |  3. Local: flutter_secure_storage           |
+-----------------------------------+     +---------------------------------------------+
```

### 2.1 File & Module Directory Map

| Path | Architectural Purpose |
| :--- | :--- |
| `lib/main.dart` | Application entrypoint; initializes DI, Firebase, LevelService, FCM, Global Background, and Listeners. |
| `lib/di/get_it.dart` | Registers `SecureStorage` and `AppCubit` singletons into `GetIt.instance`. |
| `lib/navigation/` | `my_router.dart` and `routes.dart`; defines declarative URL routes, subroutes, and guards. |
| `lib/core/cubits/` | `app_cubit.dart` and `app_state.dart`; manages minimized room states, locale, and version check. |
| `lib/core/widgets/` | `gift_image_widget.dart`, `active_frame_widget.dart`, `auto_scroll_text.dart`, SVGA players. |
| `lib/data/local/` | `secure_storage/secure_storage.dart`; encrypted key-value store for user session and locale. |
| `lib/data/remote/firebase/` | Domain services interfacing with Firestore and RTDB: |
| ├── `app_services.dart` | Fetches ZEGOCLOUD configuration (`appId`, `appSign`) from Firestore dynamically. |
| ├── `room_services.dart` | Audio room lifecycle, seat reservations, lock mechanics, and RTDB presence. |
| ├── `live_streaming_services.dart` | Video broadcast room lifecycle, 1v1 PK battle coordination, and random PK matchmaking. |
| ├── `store_service.dart` | In-app store catalog, bag inventory, and atomic purchase transactions. |
| ├── `reseller_services.dart` | Coin seller balance transfers (`balance` -> `balance`) and transaction logs. |
| ├── `level_service.dart` | XP and user level calculation based on cumulative diamond expenditures. |
| ├── `notification_service.dart` | FCM topic subscriptions (`host_{uid}`) and local heads-up notifications. |
| ├── `profile_services.dart` | User profiles, follower/following graphs, and live stream history analytics. |
| `lib/ui/streaming/` | Audio room implementation (`audio_room_page.dart` - 4,714 lines) and tool bottomsheets. |
| `lib/ui/live_streaming/` | Video broadcast implementation (`live_room_page.dart` - 4,399 lines) and PK controls. |
| `lib/ui/widgets/` | `floating_minimized_room.dart`, `global_device_ban_listener.dart`, `user_block_listener.dart`. |
| `android/` | Android native project, configured with Kotlin DSL (`build.gradle.kts`), MultiDex, and Core Desugaring. |

---

## 3. Specialized RTC & Communication Engine Deep Dive (ZEGOCLOUD)

> [!IMPORTANT]
> The user referenced *"Geo cloud or whatever they use for communication. Geocloud or Agora"*. The production codebase currently runs **ZEGOCLOUD** (SDKs: `zego_uikit`, `zego_express_engine`, and `zego_uikit_prebuilt_live_audio_room`). An enterprise migration guide to **LiveKit** is preserved in the parent workspace (`LIVEKIT_ARCHITECTURE_AND_MIGRATION_GUIDE.md` and `rtc_server/`).

### 3.1 Dual-Layer SDK Integration Architecture

The application adopts a hybrid integration approach, combining the high-level declarative state machine of `zego_uikit` with the low-level hardware control of `zego_express_engine`.

```
               +-------------------------------------------------------+
               |                sb_live Flutter Client                 |
               +---------------------------+---------------------------+
                                           |
                    +----------------------+----------------------+
                    |                                             |
                    v                                             v
       +-------------------------+                   +-------------------------+
       |       zego_uikit        |                   |   zego_express_engine   |
       |       (High-Level)      |                   |       (Low-Level)       |
       +------------+------------+                   +------------+------------+
                    |                                             |
     - Room Session (joinRoom, leaveRoom)             - Hardware SoundLevelMonitor
     - User Presence (login, logout)                  - Speaker Muting (muteSpeaker)
     - Media Control (turnMicrophoneOn)               - Low-level Audio Effects
     - In-Room Chat (sendInRoomMessage)               - BGM Mixing & Media Player
     - Video View (ZegoAudioVideoView)                - AEC / AGC / ANS Tuning
     - Cross-Room (startPlayAnotherRoom)                          |
                    |                                             |
                    +----------------------+----------------------+
                                           |
                                           v
                             +---------------------------+
                             |   ZEGOCLOUD Cloud Core    |
                             |   Global Real-Time Mesh   |
                             +---------------------------+
```

### 3.2 Dynamic Credential Architecture (Zero Hardcoded Keys)

To avoid reverse-engineering extraction of credentials from compiled Android APKs, Zego credentials are never committed as static constants.

In `lib/data/remote/firebase/app_services.dart`:
```dart
class AppServices {
  static final _firestore = FirebaseFirestore.instance;
  static final _appSettingsCollection = _firestore.collection('appSettings');
  static const String _zegoDocId = 'zego_config';

  static Future<int> getZegoAppId() async {
    final doc = await _appSettingsCollection.doc(_zegoDocId).get();
    return (doc.data()!['appId'] as num).toInt();
  }

  static Future<String> getZegoAppSign() async {
    final doc = await _appSettingsCollection.doc(_zegoDocId).get();
    return doc.data()!['appSign'] as String;
  }
}
```

### 3.3 Audio Party Room Engine (`audio_room_page.dart`)

The audio party room supports 8 to 16 seats with real-time seat locks, host controls, and audio routing.

#### 1. Engine Initialization & Audio Scenario
```dart
await ZegoUIKit().init(
  appID: await AppServices.getZegoAppId(),
  appSign: await AppServices.getZegoAppSign(),
  scenario: ZegoScenario.Default, // Optimized for multi-party audio, AEC, and AGC
);

ZegoUIKit().login(currentUser.uid, _currentUserName);
await ZegoUIKit().joinRoom(widget.roomID);

// Initial audio state: Only host unmutes immediately; listeners join muted
ZegoUIKit().turnMicrophoneOn(widget.isHost);
ZegoUIKit().setAudioOutputToSpeaker(true);
ZegoUIKit().startPlayAllAudioVideo();
```

#### 2. Seat-Driven Hardware Microphone Synchronization
When users take, leave, or are removed from seats in Firebase RTDB, the listener in `audio_room_page.dart` synchronizes the native microphone:
```dart
final bool canSpeak = widget.isHost || newCurrentUser.isApprovedSpeaker || newCurrentUser.isCoHost;
if (canSpeak) {
  if (newCurrentUser.isMuted != oldCurrentUser.isMuted) {
    ZegoUIKit().turnMicrophoneOn(!newCurrentUser.isMuted);
  }
} else {
  // Enforce hardware mute if not in an authorized speaking seat
  ZegoUIKit().turnMicrophoneOn(false);
}
```

#### 3. Real-Time Voice Activity Detection (VAD) & Sound Wave Ring
Instead of polling, the UI subscribes directly to the `soundLevel` stream of the participant's `ZegoUIKitUser`:
```dart
StreamBuilder<double>(
  stream: hostZegoUser.soundLevel,
  builder: (context, snapshot) {
    final soundLevel = snapshot.data ?? 0.0;
    final isSpeaking = soundLevel > 5.0; // VAD threshold
    return isSpeaking
        ? SVGAEasyPlayer(assetsName: "assets/svga/talking.svga")
        : const SizedBox.shrink();
  },
)
```

#### 4. BGM & Music Synchronization Pipeline (`play_music_bottomsheet.dart`)
Music can be streamed locally or broadcasted into the RTC room:
- Files are selected via `FilePicker` and copied to a permanent app document directory to ensure read permissions.
- State is broadcasted to all participants through `LiveStreamService.setRoomMusic(roomId, trackId)`.
- Low-level volume and seeking are commanded via `ZegoUIKit().seekTo(position)` or `ZegoExpressEngine`.

---

### 3.4 Video Live Streaming & 1v1 PK Battle Engine (`live_room_page.dart`)

The video live room powers interactive broadcasts and dual-host PK battles.

#### 1. Engine Initialization & Video View Mode
```dart
await ZegoUIKit().init(
  appID: await AppServices.getZegoAppId(),
  appSign: await AppServices.getZegoAppSign(),
  scenario: ZegoScenario.Broadcast, // Optimized for video uplink/downlink quality
);

ZegoExpressEngine.instance.startSoundLevelMonitor();
ZegoUIKit().updateVideoViewMode(true); // AspectFill mode

ZegoUIKit().login(currentUser.uid, _currentUserName);
await ZegoUIKit().joinRoom(widget.roomID);

ZegoUIKit().turnMicrophoneOn(widget.isHost);
ZegoUIKit().turnCameraOn(widget.isHost);
ZegoUIKit().setAudioOutputToSpeaker(true);
ZegoUIKit().startPlayAllAudioVideo();
```

#### 2. Native Video Rendering via `ZegoAudioVideoView`
Video streams are bound directly to native textures via `ZegoAudioVideoView`:
```dart
final targetUser = ZegoUIKitUser(
  id: widget.participant.userId,
  name: widget.participant.userName,
);

ZegoAudioVideoView(
  key: ValueKey('video_${widget.participant.userId}'),
  user: targetUser,
)
```

#### 3. Cross-Room Stream Relay for 1v1 PK Battles
When two hosts agree to a PK battle, neither host changes their primary room. Instead, both hosts and their respective viewers subscribe to the opponent's audio/video stream using ZEGOCLOUD's **Cross-Room Stream Relay**:

```dart
// 1. Entering PK Battle
String opponentRoomId = newPKState['opponentRoomId'] ?? '';
String opponentHostId = newPKState['opponentHostId'] ?? '';

if (opponentRoomId.isNotEmpty && opponentHostId.isNotEmpty) {
  // Subscribe to the opponent host's stream from their distinct room
  ZegoUIKit().startPlayAnotherRoomAudioVideo(
    opponentRoomId,
    opponentHostId,
  );
}

// 2. Terminating PK Battle
ZegoUIKit().stopPlayAnotherRoomAudioVideo(opponentHostId);
```

#### 4. PK Split-Screen Layout & Progress Gauge
When `_isPKMode == true`:
- The screen splits into a 50/50 horizontal split.
- The left viewport renders the local host's `ZegoAudioVideoView`.
- The right viewport renders the remote opponent host's `ZegoAudioVideoView`.
- A real-time score bar displays `myPoints` vs `opponentPoints` driven by RTDB gift events.
- A battle countdown timer triggers automatic completion upon expiration.

---

### 3.5 In-Room Signaling & Transient Data Channels

In addition to Firebase RTDB, the app utilizes ZEGOCLOUD's in-band room signaling for ultra-low-latency transient messages:
- **Text Chat**: `ZegoUIKit().sendInRoomMessage(messageText)`
- **Emoji Blast**: `ZegoUIKit().sendInRoomMessage('EMOJI_ANIM:$emoji')`
- **Listener Stream**:
  ```dart
  _messageSubscription = ZegoUIKit().getInRoomMessageStream().listen((message) {
    if (message.message.startsWith('EMOJI_ANIM:')) {
      final emoji = message.message.substring(11);
      _showFloatingEmoji(emoji, senderName: message.user.name);
      return;
    }
    // Render standard chat bubble
  });
  ```

---

## 4. Dual-Backend Data Pipeline: Firestore vs. Realtime Database (RTDB)

To balance database latency against Cloud Firestore operational costs (reads/writes billing), the architecture enforces a strict data partitioning policy termed **"Flattened Database References (The Cost Saver)"**.

```
+------------------------------------+      +------------------------------------+
|          CLOUD FIRESTORE           |      |      REALTIME DATABASE (RTDB)      |
|    (Slow, Durable, Transacted)     |      |    (High-Frequency, Ephemeral)     |
+------------------------------------+      +------------------------------------+
| - users: User profile, balance     |      | - /rooms: Active room metadata,    |
| - store: Store catalog             |      |   hostId, packagePriority, skin    |
| - users/{uid}/bag: Owned assets    |      | - /room_participants: Seat #,      |
| - reseller_transactions: Logs      |      |   mic mute state, co-host flag     |
| - appSettings/zego_config          |      | - /room_events: Overwritten gift   |
| - userLevels: XP thresholds        |      |   and emoji bursts                 |
| - banned_devices, banned_emails    |      | - /room_requests: Speaker & PK reqs|
+------------------------------------+      +------------------------------------+
```

### 4.1 Realtime Database (RTDB) Schema Blueprint

```json
{
  "rooms": {
    "<roomId>": {
      "hostId": "firebase_uid",
      "hostName": "John Doe",
      "hostPicture": "https://...",
      "hostCountry": "BD",
      "isActive": true,
      "participantCount": 14,
      "isMoveAllowed": true,
      "isSeatApprovalRequired": false,
      "isLocked": false,
      "password": null,
      "packagePriority": 3,
      "packageBadgeUrl": "https://...",
      "backgroundUrl": "https://...",
      "pkState": {
        "isPK": true,
        "opponentRoomId": "room_xyz",
        "opponentHostId": "uid_abc",
        "pkEndTime": 1725700000000
      }
    }
  },
  "room_participants": {
    "<roomId>": {
      "<userId>": {
        "userId": "firebase_uid",
        "displayId": "100452",
        "userName": "Jane",
        "userPicture": "https://...",
        "seatNo": 2,
        "isCoHost": false,
        "isMuted": false,
        "isOnline": true,
        "roomCoins": 1500,
        "joinedAt": 1725690000000
      }
    }
  },
  "room_events": {
    "<roomId>": {
      "gift": {
        "senderId": "uid_1",
        "senderName": "Jane",
        "receiverName": "Host",
        "giftValue": 500,
        "hitCount": 5,
        "giftAnimationUrl": "assets/svga/rocket.svga",
        "timestamp": 1725695000000
      }
    }
  },
  "room_requests": {
    "<roomId>": {
      "speaker_requests": { "<reqId>": { "userId": "...", "userName": "..." } },
      "pk_invites": { "<opponentRoomId>": { "senderRoomId": "...", "status": "pending" } }
    }
  }
}
```

### 4.2 Presence & Disconnection Recovery (`onDisconnect`)

Network drops on mobile devices are handled gracefully using Firebase RTDB `.info/connected` and native disconnect hooks:
```dart
// Mark participant offline upon socket termination
await participantRef.child('isOnline').onDisconnect().set(false);

// If host disconnects, the room remains intact temporarily to allow reconnects
```

---

## 5. Economy, Monetization & Gamification Systems

### 5.1 Dynamic Store & Inventory System (`store_service.dart`)
- **Categories**: Packages (Royal, King, Queen, Crown), Room Screens/Skins, Vehicles (Entrance animations), Frames (SVGA borders), Badges.
- **Expiration Policy**: Packages grant 365-day validity; standard cosmetics grant 30-day validity. If already owned, subsequent purchases incrementally extend the expiration timestamp.
- **Transactions**: Executed via Firestore `runTransaction` to guarantee balance sufficiency before decrementing diamonds and updating the user's `bag` subcollection.

### 5.2 Reseller & Agency Distribution Hub (`reseller_services.dart`)
Authorized coin sellers can recharge diamonds directly to client accounts by ID:
1. Reseller searches target user via numeric `displayId`.
2. An atomic Firestore transaction verifies the reseller's `balance >= amount`.
3. Decrements `balance` on the seller doc.
4. Increments `balance` on the recipient doc.
5. Inserts a permanent audit record into `reseller_transactions`.

### 5.3 Dynamic User Level System (`level_service.dart`)
User levels are computed dynamically at runtime based on cumulative diamonds spent (`totalSent`):
- Thresholds are fetched once at startup from Firestore `userLevels` and sorted descending.
- If offline, falls back to a hardcoded 20-tier bracket (ranging from 50,000 to 240,000,000 diamonds).

### 5.4 Hardware-Accelerated SVGA Gift Pipeline
- When a gift event is received from RTDB `room_events/$roomId/gift`, `_showGiftOverlay()` queues the animation.
- Rendered using `SVGAAnimationController` and `SVGAImage`.
- Includes combo hit counter increments and real-time audio playback (`audioplayers`).

---

## 6. App Lifecycle, Floating PIP & Security Hardening

### 6.1 Floating Minimized Room (`floating_minimized_room.dart`)
The app allows users to minimize live rooms and continue browsing:
- **State Mounting**: `FloatingMinimizedRoom` is injected globally into `MaterialApp.builder` in `main.dart`.
- **State Representation**: Controlled via `AppCubit` (`minimizedRoom` in `AppState`).
- **RTC Continuity**: The ZEGOCLOUD session is preserved when the room page pops. Audio continues to route via the device speaker.
- **Re-entrance & Teardown**: Tapping the floating badge executes `MyRouter.router.push` back to `Routes.audioRoom` or `Routes.liveStream`. Tapping the close icon cleans up RTDB presence and invokes `ZegoUIKit().leaveRoom()` and `ZegoUIKit().logout()`.

### 6.2 Security, Device Bans & Moderation
- **Hardware Device Ban (`global_device_ban_listener.dart`)**: Obtains hardware UDID via `FlutterUdid.udid`. Listens in real time to `banned_devices`. Upon detection, forces local storage wipe, signs out from FirebaseAuth and GoogleSignIn, and locks the UI behind a non-dismissible modal.
- **User Account Suspension (`user_block_listener.dart`)**: Listens to `users/{uid}` (`isBlocked == true`) and `banned_emails`.
- **Force Update (`force_update_screen.dart`)**: Compares installed version (`package_info_plus`) against `appSettings/app_version` via semver (`version` package), redirecting users to the direct download APK URL if outdated.

---

## 7. Migration Playbook: Moving from ZegoCloud to LiveKit SFU

As evidenced by `LIVEKIT_ARCHITECTURE_AND_MIGRATION_GUIDE.md` and the companion `rtc_server/` repository, an architectural transition towards self-hosted LiveKit SFU is planned.

### 7.1 Architecture Comparison Matrix

| Architectural Vector | Current: ZEGOCLOUD | Future: LiveKit SFU (`rtc_server`) |
| :--- | :--- | :--- |
| **Media Plane Ownership** | Proprietary PaaS Cloud | Fully self-hosted Go SFU (Docker on Ubuntu VPS) |
| **Authentication Plane** | Static `appId` + `appSign` | Cryptographic JWTs minted per-session by `rtc_server` |
| **Token Endpoint** | N/A (Direct SDK login) | `POST http://localhost:5000/api/token` |
| **Media Transport** | Proprietary UDP protocol | Standard WebRTC SFU (RTP/RTCP, ICE over UDP 50K-60K) |
| **PK Cross-Room Stream** | `startPlayAnotherRoomAudioVideo` | SFU Room Composite or Egress relay track |
| **Bandwidth Optimization** | SDK internal bitrate adaptation | Simulcast (3 spatial layers) + Dynacast |
| **Licensing / Cost** | Per-minute participant billing | Zero licensing fees; bare-metal bandwidth costs only |

### 7.2 Method & Concept Transformation Cheat Sheet

```dart
// -------------------------------------------------------------
// 1. INITIALIZATION & ROOM JOINING
// -------------------------------------------------------------
// [LEGACY ZEGOCLOUD]
await ZegoUIKit().init(appID: appId, appSign: appSign, scenario: ZegoScenario.Default);
ZegoUIKit().login(userId, userName);
await ZegoUIKit().joinRoom(roomId);

// [MODERN LIVEKIT]
final room = Room();
await room.connect(
  'wss://livekit.yourdomain.com',
  jwtTokenFromNodeRtcServer,
  roomOptions: const RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
  ),
);

// -------------------------------------------------------------
// 2. MICROPHONE CONTROL
// -------------------------------------------------------------
// [LEGACY ZEGOCLOUD]
ZegoUIKit().turnMicrophoneOn(true);

// [MODERN LIVEKIT]
await room.localParticipant?.setMicrophoneEnabled(true);

// -------------------------------------------------------------
// 3. CAMERA CONTROL & VIDEO RENDERING
// -------------------------------------------------------------
// [LEGACY ZEGOCLOUD]
ZegoUIKit().turnCameraOn(true);
ZegoAudioVideoView(user: targetUser);

// [MODERN LIVEKIT]
await room.localParticipant?.setCameraEnabled(true);
VideoTrackRenderer(videoTrack);

// -------------------------------------------------------------
// 4. VOICE ACTIVITY DETECTION (VAD)
// -------------------------------------------------------------
// [LEGACY ZEGOCLOUD]
hostZegoUser.soundLevel.listen((level) => isSpeaking = level > 5.0);

// [MODERN LIVEKIT]
room.addListener(() {
  final activeSpeakers = room.activeSpeakers;
  // Contains List<Participant> currently speaking
});

// -------------------------------------------------------------
// 5. IN-ROOM MESSAGING / DATA CHANNEL
// -------------------------------------------------------------
// [LEGACY ZEGOCLOUD]
ZegoUIKit().sendInRoomMessage("Hello");

// [MODERN LIVEKIT]
await room.localParticipant?.publishData(
  utf8.encode(jsonEncode({"type": "chat", "msg": "Hello"})),
  reliability: Reliability.reliable,
);
```

---

## 8. Engineer Quick-Start & Verification Checklist

When debugging or extending the RTC features in this codebase, adhere to the following checklist:

1. **Checking Zego Credentials**: Ensure `appSettings/zego_config` exists in Cloud Firestore with valid `appId` (number) and `appSign` (string).
2. **Microphone Permissions**: Android requires `android.permission.RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS`. Ensure runtime permission is granted via `permission_handler` before invoking `turnMicrophoneOn`.
3. **Bluetooth Audio Routing**: If users report Bluetooth headset silence, ensure `BLUETOOTH_CONNECT` permission is declared and `ZegoUIKit().setAudioOutputToSpeaker(false)` is negotiated.
4. **RTDB Cost Safeguards**: Never attach deep recursive `.onValue` listeners to `/rooms` or `/users`. Listen strictly to leaf nodes (`/room_participants/$roomId` or `/room_events/$roomId/gift`).
5. **Memory Leak Prevention**: Every `StreamSubscription` created in `audio_room_page.dart` and `live_room_page.dart` MUST be explicitly cancelled inside `dispose()`. Always call `ZegoUIKit().leaveRoom()` and `ZegoUIKit().logout()` prior to screen pop.
