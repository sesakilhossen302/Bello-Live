# Phase 1 Context: RTC Communication Backend Server Migration

## Context & Motivation
The real-time communications backend (LiveKit SFU and Node.js token control plane) powering all audio party rooms and live video streaming (including 1v1 PK battles) was hosted on a legacy VPS (`129.212.226.12`). The user has deployed and started the new backend server at `167.71.207.84`.

## Server Details (Deployed & Running)
- **Host IP**: `167.71.207.84`
- **LiveKit SFU URL**: `ws://167.71.207.84:7880`
- **Token / API Base URL**: `http://167.71.207.84:5000/api`

## Locked Implementation Decisions

### 1. Zero-Downtime Mobile Cutover Strategy
- **Mechanism**: The Flutter app architecture implements dynamic endpoint resolution via [`AppServices.getLiveKitConfig()`](file:///d:/01_Office_Work/My%20Client%20Work/sbliveapp_codebase/lib/data/remote/firebase/app_services.dart).
- **Cutover Path**: Update Firestore document `appSettings/livekit_config` with `liveKitUrl: "ws://167.71.207.84:7880"` and `tokenServerUrl: "http://167.71.207.84:5000/api"`.
- **Client Fallback**: [`AppConfig.defaultLiveKitUrl`](file:///d:/01_Office_Work/My%20Client%20Work/sbliveapp_codebase/lib/core/config/app_config.dart) updated to `'ws://167.71.207.84:7880'` and `AppConfig.defaultTokenServerUrl` updated to `'http://167.71.207.84:5000/api'`.

### 2. Server Architecture & Protocols
- **LiveKit SFU**:
  - Handles multi-participant audio seats (up to 12 seats per party room) and video streaming/PK battles.
  - Signaling: WebSocket (`ws://` or `wss://` on port 7880 or 443).
  - Media Transport: UDP port `7882` (critical for low-latency voice and video).
  - Fallback: TCP port `7881`.
- **Token Server**:
  - Signs JWT tokens using matching `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET`.
  - Exposes `POST /token` accepting `{roomName, participantName, participantIdentity, role, roomType}`.

### 3. Client Resilience
- Update `LiveKitService` in Flutter to handle connection failure states gracefully with explicit logging and user-friendly error banners when the backend server is temporarily unreachable.
