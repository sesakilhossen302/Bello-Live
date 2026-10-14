# Self-Hosted LiveKit Infrastructure & Cross-App Migration Guide
### Complete Reference for Connecting Applications (Migrating from Agora / ZegoCloud) to the Bello Live Self-Hosted LiveKit Infrastructure

---

## 1. Executive Summary & Architecture Overview

**Bello Live (`picture_live`)** has fully migrated from third-party managed RTC clouds (ZegoCloud / Agora) to our **own self-hosted LiveKit SFU (Selective Forwarding Unit) infrastructure**.

This document explains:
1. **How Bello Live connects** to our self-hosted LiveKit Media Server and Token Control Plane (`rtc_server`).
2. **How another application** (currently running **Agora** or **ZegoCloud**) can connect to this **exact same LiveKit infrastructure** (or replicate it on another VPS).
3. **Step-by-step migration blueprints** mapping every Agora and ZegoCloud SDK call (Audio Rooms, Live Video Broadcasting, Multi-Guest Co-Hosting, 1v1 PK Battles, In-Room Chat/Emoji DataChannels, and Voice Activity Detection) to our `LiveKitService` wrapper.

---

## 2. How Bello Live Connects to Our Self-Hosted Infrastructure

### 2.1 Infrastructure Endpoints & Server Topology

Our LiveKit infrastructure runs on our dedicated Ubuntu VPS (`167.71.207.84`) and consists of two core services:

| Component | Protocol & Port | Production Endpoint | Purpose |
| :--- | :--- | :--- | :--- |
| **1. LiveKit SFU Server** | WebSocket (`ws://` / `wss://`) Port `7880` | `ws://167.71.207.84:7880` | Routes WebRTC audio, simulcast video, and SCTP data channels between participants. |
| **2. RTC Token Server (`rtc_server`)** | HTTP REST (`http://` / `https://`) Port `5000` | `http://167.71.207.84:5000/api` | Node.js service that signs cryptographic LiveKit JWT access tokens using the server's `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET`. |
| **3. WebRTC Media Ports** | UDP `50000-60000`, TCP `7881` | `167.71.207.84:50000-60000/udp` | Low-latency UDP/ICE media transport streams for audio and video tracks. |

### 2.2 End-to-End Connection Flow in Bello Live

```
+-----------------------------------------------------------------------------------+
|                        MOBILE CLIENT (Bello Live / Target App)                       |
|                                                                                   |
|  1. AppServices.getLiveKitConfig()                                                |
|     - Fetches dynamic endpoints from Firestore (`appSettings/livekit_config`)     |
|     - Falls back to AppConfig (`ws://167.71.207.84:7880` & `:5000/api`)           |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          | 2. HTTP POST /api/token
                                          |    { roomName, participantIdentity,
                                          |      participantName, role, roomType }
                                          v
+-----------------------------------------------------------------------------------+
|                   SELF-HOSTED TOKEN SERVER (`rtc_server` :5000)                   |
|                                                                                   |
|  - Validates request parameters & role (`HOST`, `PARTICIPANT`, `LISTENER`)        |
|  - Signs JWT using LiveKit Server API Key & Secret                                |
|  - Returns: { "success": true, "token": "eyJhbGciOiJIUzI1NiIs..." }               |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          | 3. Returns Signed JWT Token
                                          v
+-----------------------------------------------------------------------------------+
|                    LIVEKIT SFU MEDIA SERVER (`livekit-server` :7880)              |
|                                                                                   |
|  4. room.connect("ws://167.71.207.84:7880", token)                                |
|     - Establishes WebSocket signaling + ICE/UDP media transport                   |
|     - Publishes Opus Audio (64kbps, DTX off) & H.264 3-layer Simulcast Video      |
|     - Subscribes to Remote Tracks & SCTP DataChannels (Chat, Emoji, PK Streams)   |
+-----------------------------------------------------------------------------------+
```

---

## 3. Server & Backend Specification (For Sharing or Re-Deploying)

### 3.1 Option A: Reusing the Existing Bello Live LiveKit Infrastructure for Another App
Multiple applications can share the **exact same LiveKit Server (`ws://167.71.207.84:7880`) and Token Server (`http://167.71.207.84:5000/api`)** simultaneously without interfering with Bello Live!
- **Why?** LiveKit isolates media by `roomName`.
- **Best Practice when sharing**: Prefix the `roomName` in the second application with an app identifier (for example, `otherapp_room_${roomId}`) so room IDs from the second app never collide with Bello Live room IDs.

### 3.2 Token Server API Contract (`POST /api/token`)
The client requests a token via `POST http://167.71.207.84:5000/api/token`:

#### Request Headers
```http
Content-Type: application/json
```

#### Request Body
```json
{
  "roomName": "room_987654",
  "participantName": "John Doe",
  "participantIdentity": "user_uid_123",
  "role": "HOST",
  "roomType": "VIDEO"
}
```
- `roomName` (`String`): Unique identifier of the audio or video room.
- `participantName` (`String`): Display name shown to other participants.
- `participantIdentity` (`String`): Unique user ID (`uid`) used to map video views and active speaker indicators.
- `role` (`String`):
  - `"HOST"`: Full publish (`canPublish: true`, `canPublishData: true`, `canSubscribe: true`)
  - `"PARTICIPANT"` / `"SPEAKER"`: Co-host or audio room seat holder (`canPublish: true`, `canPublishData: true`, `canSubscribe: true`)
  - `"LISTENER"`: Viewer/audience member (`canPublish: false`, `canPublishData: true`, `canSubscribe: true`)
- `roomType` (`String`): `"VIDEO"` or `"AUDIO"`.

#### Response Body (`200 OK`)
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 3.3 Option B: How the Node.js Token Server (`rtc_server`) Works Internally
If you ever deploy a separate token server or add an endpoint directly inside another app's existing Node.js backend, here is the exact token-signing implementation using `livekit-server-sdk`:

```javascript
// npm install express cors dotenv livekit-server-sdk
const express = require('express');
const cors = require('cors');
const { AccessToken } = require('livekit-server-sdk');

const app = express();
app.use(cors());
app.use(express.json());

const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY;
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET;

app.post('/api/token', async (req, res) => {
  try {
    const { roomName, participantName, participantIdentity, role } = req.body;

    if (!roomName || !participantIdentity) {
      return res.status(400).json({ success: false, error: 'Missing roomName or participantIdentity' });
    }

    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity: String(participantIdentity),
      name: participantName || 'User',
      ttl: '24h',
    });

    // Grant permissions across roles (client enforces hardware mic/cam state,
    // allowing instant seat promotion from viewer to co-host without reconnecting)
    at.addGrant({
      roomJoin: true,
      room: String(roomName),
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();
    return res.status(200).json({ success: true, token });
  } catch (err) {
    console.error('Token generation failed:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

app.listen(5000, '0.0.0.0', () => console.log('RTC Token Server listening on port 5000'));
```

---

## 4. Concept & API Mapping: Agora / ZegoCloud $\rightarrow$ LiveKit (`LiveKitService`)

When migrating another application from **Agora** or **ZegoCloud**, use this reference table to replace legacy SDK calls:

| Feature / Use Case | ZegoCloud (`zego_uikit` / `zego_express`) | Agora (`agora_rtc_engine`) | Bello Live LiveKit (`LiveKitService.instance`) |
| :--- | :--- | :--- | :--- |
| **SDK Initialization & Join** | `ZegoUIKit().init(appID, appSign)` + `ZegoUIKit().joinRoom(roomId)` | `createAgoraRtcEngine()` + `engine.initialize()` + `engine.joinChannel(...)` | `LiveKitService.instance.connectRoom(roomName: ..., userId: ..., userName: ..., role: ..., isVideo: ..., isHost: ...)` |
| **Leave / Disconnect** | `ZegoUIKit().leaveRoom()` | `engine.leaveChannel()` + `engine.release()` | `LiveKitService.instance.disconnect()` |
| **Toggle Microphone** | `ZegoUIKit().turnMicrophoneOn(bool)` | `engine.muteLocalAudioStream(!bool)` / `enableLocalAudio(bool)` | `LiveKitService.instance.setMicrophoneEnabled(bool)` |
| **Toggle Camera** | `ZegoUIKit().turnCameraOn(bool)` | `engine.muteLocalVideoStream(!bool)` / `enableLocalVideo(bool)` | `LiveKitService.instance.setCameraEnabled(bool)` |
| **Switch Front/Back Camera** | `ZegoUIKit().useFrontCamera(bool)` | `engine.switchCamera()` | `await LiveKitService.instance.flipCamera()` |
| **Mute Speaker Output** | `ZegoExpressEngine.instance.muteSpeaker(bool)` | `engine.muteAllRemoteAudioStreams(bool)` | `LiveKitService.instance.setSpeakerMuted(bool)` |
| **Render Video View (Local & Remote)** | `ZegoAudioVideoView(user: zegoUser)` | `AgoraVideoView(controller: VideoViewController(...))` | `LiveKitService.instance.buildVideoView(userId, isOpponent: false, fit: BoxFit.cover)` |
| **Voice Activity / Talking Indicator** | `zegoUser.soundLevel` (`Stream<double>`) | `onAudioVolumeIndication` callback | `LiveKitService.instance.activeSpeakersStream` (`Stream<List<String>>`) |
| **In-Room Chat & Fast Commands** | `ZegoUIKit().sendInRoomMessage(msg)` & `getInRoomMessageStream()` | `engine.sendStreamMessage(...)` / Agora RTM | `LiveKitService.instance.sendChatMessage(msg)` & `chatMessagesStream` |
| **1v1 PK Battle (Cross-Room Stream)** | `ZegoUIKit().startPlayAnotherRoomAudioVideo(oppRoomId, oppHostId)` | `engine.startOrUpdateChannelMediaRelay(...)` | `LiveKitService.instance.connectOpponentPKRoom(opponentRoomId: ..., opponentHostId: ...)` |
| **End 1v1 PK Battle** | `ZegoUIKit().stopPlayAnotherRoomAudioVideo(oppHostId)` | `engine.stopChannelMediaRelay()` | `LiveKitService.instance.disconnectOpponentPKRoom()` |

---

## 5. Step-by-Step Guide to Migrate Another Flutter Application

Follow these 6 steps to migrate any existing Flutter app from Agora or ZegoCloud to our LiveKit infrastructure.

### Step 1: Update `pubspec.yaml` Dependencies

1. **Remove** Agora or ZegoCloud packages (`agora_rtc_engine`, `zego_uikit`, `zego_express_engine`, `zego_uikit_prebuilt_live_audio_room`, etc.).
2. **Add** `livekit_client`, `flutter_webrtc`, and `http`:

```yaml
dependencies:
  livekit_client: ^2.2.8
  flutter_webrtc: ^1.2.1
  http: ^1.4.0
  permission_handler: ^12.0.1
```

Run `flutter pub get`.

---

### Step 2: Configure Native Platform Permissions (Android & iOS)

#### Android (`android/app/src/main/AndroidManifest.xml`)
Ensure the following permissions and `usesCleartextTraffic="true"` (required if connecting via `http://` or `ws://` IP without SSL) are present:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <application
        android:usesCleartextTraffic="true"
        ...>
```

#### iOS (`ios/Runner/Info.plist`)
Ensure Camera and Microphone usage descriptions are included:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for live video streaming.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for live audio and voice chat rooms.</string>
```

---

### Step 3: Add `AppConfig` and Remote Config (`lib/core/config/app_config.dart`)

Create `lib/core/config/app_config.dart` in the target application pointing to our self-hosted LiveKit server (`167.71.207.84`):

```dart
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Default LiveKit SFU WebSocket URL (Self-Hosted VPS).
  static String defaultLiveKitUrl = 'ws://167.71.207.84:7880';

  /// Default Node.js RTC Token Control Plane URL (`rtc_server`).
  static String defaultTokenServerUrl = 'http://167.71.207.84:5000/api';

  /// Active runtime endpoints (initialized from Remote Config/Firestore or fallbacks)
  static String liveKitUrl = defaultLiveKitUrl;
  static String tokenServerUrl = defaultTokenServerUrl;

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
```

*(Optional)* If the target app uses Firestore, add `AppServices.getLiveKitConfig()` reading from `appSettings/livekit_config` (`{ "liveKitUrl": "ws://167.71.207.84:7880", "tokenServerUrl": "http://167.71.207.84:5000/api" }`) so server IPs can be rotated remotely without an app store update.

---

### Step 4: Copy the Unified `LiveKitService` (`lib/core/services/livekit_service.dart`)

Copy `lib/core/services/livekit_service.dart` from `sbliveapp_codebase` into the target application. This single service provides:
1. **Automatic JWT Token Fetching** (`fetchToken()`) from `http://167.71.207.84:5000/api/token`.
2. **Primary Room Connection** (`connectRoom()`) with studio-grade 64 kbps Opus audio (`dtx: false`) and 3-layer H.264 video simulcast (`180p`, `360p`, `720p`).
3. **Automatic Bluetooth & Speakerphone Audio Routing** (`applyAudioRouting()`).
4. **Dual-Room 1v1 PK Battle Support** (`connectOpponentPKRoom()` and `disconnectOpponentPKRoom()`).
5. **Zero-Latency Video Widget Builder** (`buildVideoView()`).
6. **DataChannel Chat & Emoji Streams** (`sendChatMessage()`, `sendEmoji()`, `chatMessagesStream`, `dataMessagesStream`).

---

### Step 5: Integrate into Audio Rooms, Video Live Rooms, and PK Battles

#### A. Joining an Audio Party Room (`isVideo: false`)
```dart
await LiveKitService.instance.connectRoom(
  roomName: roomId, // Tip: prefix with 'app2_$roomId' if sharing the same server with Bello Live
  userId: currentUserId,
  userName: currentUserName,
  role: isHost ? 'HOST' : 'PARTICIPANT',
  isVideo: false,
  isHost: isHost, // Host starts with mic enabled; audience starts with mic muted
);
```

#### B. Promoting an Audience Member to a Speaking Seat (Audio or Co-Host Seat)
Because our Token Server issues tokens with `canPublish: true` while `connectRoom` keeps audience members muted at the hardware level, promoting a viewer to a speaker seat requires **zero reconnection**:
```dart
// When user takes a seat or is unmuted:
final bool canSpeak = isHost || isApprovedSpeaker || isCoHost;
await LiveKitService.instance.setMicrophoneEnabled(canSpeak && !isMuted);

// If in a video co-host seat:
await LiveKitService.instance.setCameraEnabled(canSpeak && isCameraOn);
```

#### C. Joining a Video Broadcast Room (`isVideo: true`)
```dart
await LiveKitService.instance.connectRoom(
  roomName: roomId,
  userId: currentUserId,
  userName: currentUserName,
  role: isHost ? 'HOST' : 'PARTICIPANT',
  isVideo: true,
  isHost: isHost, // Host starts with mic & camera enabled; viewers start with both off
);
```

#### D. Rendering Video Streams (Host, Co-Host, or PK Opponent)
Replace `AgoraVideoView` or `ZegoAudioVideoView` with a reactive stateful widget that listens to `remoteParticipantsChangedStream`:

```dart
class ParticipantVideoView extends StatefulWidget {
  final String userId;
  final bool isOpponent;
  final bool isCameraOn;

  const ParticipantVideoView({
    super.key,
    required this.userId,
    this.isOpponent = false,
    this.isCameraOn = true,
  });

  @override
  State<ParticipantVideoView> createState() => _ParticipantVideoViewState();
}

class _ParticipantVideoViewState extends State<ParticipantVideoView> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // Rebuild automatically when tracks are published/subscribed/muted/flipped
    _sub = LiveKitService.instance.remoteParticipantsChangedStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCameraOn) {
      return Container(color: Colors.black);
    }
    return LiveKitService.instance.buildVideoView(
      widget.userId,
      isOpponent: widget.isOpponent,
      fit: BoxFit.cover,
    );
  }
}
```

#### E. Implementing 1v1 PK Battles (Cross-Room Streaming)
In Bello Live, 1v1 PK Battles do **not** require complex server-side media relay jobs. Instead, `LiveKitService` maintains a secondary `Room` (`_opponentRoom`) that subscribes to the opponent host's room as a `LISTENER`:

```dart
// 1. When PK Battle starts (executed on both Hosts AND Viewers):
await LiveKitService.instance.connectOpponentPKRoom(
  opponentRoomId: opponentRoomId,
  opponentHostId: opponentHostId,
);

// 2. Render Split-Screen UI:
Row(
  children: [
    Expanded(
      child: ParticipantVideoView(
        userId: primaryHostId,
        isOpponent: false,
      ),
    ),
    Expanded(
      child: ParticipantVideoView(
        userId: opponentHostId,
        isOpponent: true, // Pulls track from _opponentRoom!
      ),
    ),
  ],
)

// 3. When PK Battle ends:
await LiveKitService.instance.disconnectOpponentPKRoom();
```

#### F. Displaying Voice Activity (Talking Ring / Sound Wave Indicator)
```dart
StreamBuilder<List<String>>(
  stream: LiveKitService.instance.activeSpeakersStream,
  builder: (context, snapshot) {
    final activeSpeakerIds = snapshot.data ?? const [];
    final isSpeaking = !participant.isMuted && activeSpeakerIds.contains(participant.userId);
    if (!isSpeaking) return const SizedBox.shrink();
    return YourTalkingRingAnimationWidget();
  },
)
```

#### G. In-Room Chat & Emoji DataChannel Messaging
```dart
// Listen for incoming chat messages:
_chatSub = LiveKitService.instance.chatMessagesStream.listen((msg) {
  // msg.userId, msg.userName, msg.message, msg.timestamp
});

// Listen for custom DataChannel packets (e.g., emojis, gifts, room commands):
_dataSub = LiveKitService.instance.dataMessagesStream.listen((json) {
  if (json['type'] == 'emoji') {
    showFloatingEmoji(json['emoji'], senderName: json['userName']);
  }
});

// Send chat message:
await LiveKitService.instance.sendChatMessage("Hello everyone!");

// Send emoji burst:
await LiveKitService.instance.sendEmoji("🔥");
```

---

### Step 6: Proper Teardown & Minimized Room (PiP) Handling

Always ensure `LiveKitService.instance.disconnect()` is only called when the user **truly leaves** the room—not when minimizing into an in-app Picture-in-Picture (Floating Room) overlay:

```dart
@override
void dispose() {
  _chatSub?.cancel();
  _dataSub?.cancel();

  // Only disconnect WebRTC session if the room is NOT minimized into PiP
  if (!isMinimizingRoom) {
    LiveKitService.instance.disconnect();
  }
  super.dispose();
}
```

---

## 6. Verification & Troubleshooting Checklist for Target Applications

1. **Cleartext Traffic Blocked on Android (`SocketException` / `Cleartext HTTP traffic not permitted`)**:
   - Ensure `android:usesCleartextTraffic="true"` is set on `<application>` in `AndroidManifest.xml` when using `http://167.71.207.84:5000/api` and `ws://167.71.207.84:7880`.
2. **Audio Plays Out of Earpiece Instead of Loudspeaker**:
   - `LiveKitService.instance.applyAudioRouting()` automatically invokes `rtc.Helper.setSpeakerphoneOnButPreferBluetooth()` both on room join and whenever a remote audio track is subscribed (`TrackSubscribedEvent`). Do not override audio routing with conflicting third-party audio plugins.
3. **Room ID Collisions Across Multiple Apps**:
   - If App A (`Bello Live`) and App B share `ws://167.71.207.84:7880`, prefix `roomName` in App B (e.g., `appB_${roomId}`) when calling `LiveKitService.instance.connectRoom(...)` and `connectOpponentPKRoom(...)`.
4. **Black Video Screen After Joining**:
   - Ensure the widget displaying `buildVideoView()` subscribes to `LiveKitService.instance.remoteParticipantsChangedStream` and calls `setState(() {})` when the remote video track finishes negotiating (`TrackSubscribedEvent`).

