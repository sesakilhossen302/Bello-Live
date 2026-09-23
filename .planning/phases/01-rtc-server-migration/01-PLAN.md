# Phase 1 Plan: RTC Communication Backend Server Migration (Audio & Video)

## Phase Objective
Safely cut over the real-time audio and video communications infrastructure from the stopped/legacy server (`129.212.226.12`) to the newly deployed active server (`167.71.207.84`), verify media routing for audio seats and video streaming/PK battles, and execute a dynamic, zero-downtime cutover via Firestore and Flutter client configuration.

## Active Server Endpoints
- **LiveKit WebSocket URL**: `ws://167.71.207.84:7880`
- **Token API Base URL**: `http://167.71.207.84:5000/api`

## System Components Involved

```
┌───────────────────────────────────────────────────────────────────────┐
│                          FLUTTER CLIENT                               │
│  - lib/core/services/livekit_service.dart (WebRTC Audio/Video)        │
│  - lib/core/config/app_config.dart (Static Endpoint Defaults)         │
│  - lib/data/remote/firebase/app_services.dart (Dynamic Remote Config) │
└───────────────────────┬──────────────────────┬────────────────────────┘
                        │ 1. Dynamic Config    │
                        ▼                      │
┌───────────────────────────────┐              │
│       CLOUD FIRESTORE         │              │
│  appSettings/livekit_config   │              │
│  - liveKitUrl                 │              │
│  - tokenServerUrl             │              │
└───────────────────────────────┘              │
                                               │
               ┌───────────────────────────────┴────────────────────────┐
               │                                                        │
               ▼ 2. POST /token (JWT)                                   ▼ 3. WSS WebRTC Audio & Video
┌───────────────────────────────┐              ┌────────────────────────────────┐
│      RTC TOKEN SERVER         │              │        LIVEKIT SFU             │
│  - Port 5000 (or HTTPS /api)  │─────────────▶│  - Port 7880 / 443 (Signaling) │
│  - LIVEKIT_API_KEY & SECRET   │ Signs Access │  - Port 7881 (TCP WebRTC)      │
│  - Signs participant JWTs     │ Tokens       │  - Port 7882/UDP (Media Audio) │
└───────────────────────────────┘              └────────────────────────────────┘
```

## Requirements Covered
- **MIG-01**: Deploy & configure LiveKit SFU on the new host environment with media routing and ports.
- **MIG-02**: Deploy Node.js/TypeScript RTC Token Server with API key/secret matching the SFU.
- **MIG-03**: Secure signaling and token exchange with SSL/TLS (HTTPS/WSS) via domain & reverse proxy.
- **MIG-04**: Execute instant client cutover via Firestore `appSettings/livekit_config`.
- **MIG-05**: Update static client fallbacks in `lib/core/config/app_config.dart`.
- **MIG-06**: Add connection error handling, timeouts, and user feedback in `LiveKitService`.

---

## Tasks

### Task 1: New Server Host & Firewall Preparation (MIG-01)
- **Target**: New Host / VPS (Ubuntu / Debian / Docker)
- **Port Mapping**:
  - `7880/TCP`: LiveKit HTTP/WebSocket signaling
  - `7881/TCP`: LiveKit WebRTC TCP fallback
  - `7882/UDP`: LiveKit WebRTC UDP media transport (voice seats & video streams)
  - `5000/TCP`: RTC Token Server (if direct) or `80`/`443` (via reverse proxy)
- **Firewall Rules (UFW / Cloud Security Groups)**:
  ```bash
  sudo ufw allow 7880/tcp
  sudo ufw allow 7881/tcp
  sudo ufw allow 7882/udp
  sudo ufw allow 5000/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  ```

### Task 2: LiveKit SFU Deployment & Configuration (MIG-01)
- **Configuration File (`livekit.yaml`)**:
  ```yaml
  port: 7880
  bind_addresses:
    - ""
  rtc:
    tcp_port: 7881
    udp_port: 7882
    use_external_ip: true
  turn:
    enabled: false
  keys:
    API_KEY_HERE: API_SECRET_HERE
  logging:
    level: info
  ```
- **Docker Run / Compose**:
  ```bash
  docker run -d --name livekit-server \
    --restart unless-stopped \
    --net=host \
    -v $PWD/livekit.yaml:/livekit.yaml \
    livekit/livekit-server:latest \
    --config /livekit.yaml
  ```

### Task 3: Token Control Plane Deployment (MIG-02)
- **Description**: Deploy the token generator microservice (e.g., from `rtc_server`).
- **Environment Variables**:
  - `PORT=5000`
  - `LIVEKIT_API_KEY=<MATCHING_API_KEY>`
  - `LIVEKIT_API_SECRET=<MATCHING_API_SECRET>`
  - `LIVEKIT_URL=ws://127.0.0.1:7880` (or local loopback)
- **Contract / Endpoints**:
  - `GET /health` -> `{"status": "ok"}`
  - `POST /token` ->
    - Input: `{ "roomName": string, "participantName": string, "participantIdentity": string, "role": string, "roomType": "AUDIO"|"VIDEO" }`
    - Output: `{ "success": true, "token": "<JWT_STRING>" }`

### Task 4: Reverse Proxy & SSL/TLS Setup (MIG-03)
- **Description**: Configure Caddy or Nginx with Let's Encrypt SSL certificates for domain routing (e.g. `livekit.yourdomain.com` and `rtc-api.yourdomain.com`).
- **Benefits**: Eliminates cleartext WS/HTTP transmission, ensures compliance with iOS ATS (App Transport Security) and Android modern network security configs.

### Task 5: Zero-Downtime Dynamic Cutover via Firestore (MIG-04)
- **Target**: Cloud Firestore document `appSettings/livekit_config`
- **Action**:
  Update fields:
  ```json
  {
    "liveKitUrl": "wss://new-livekit-server:7880",
    "tokenServerUrl": "https://new-token-server/api",
    "lastMigratedAt": "2026-09-22T00:00:00Z"
  }
  ```
- **Impact**: All installed apps fetch this document on room join ([AppServices.getLiveKitConfig()](file:///d:/01_Office_Work/My%20Client%20Work/sbliveapp_codebase/lib/data/remote/firebase/app_services.dart#L16-L41)) and immediately route all audio and video rooms to the new server without requiring an app store update!

### Task 6: Client Fallbacks & Connection Resilience (MIG-05, MIG-06)
- **Files**:
  - `lib/core/config/app_config.dart`: Update static default URLs to point to the new server as backup.
  - `lib/core/services/livekit_service.dart`:
    - Add explicit timeout and error classification (e.g. Server Unreachable, Invalid Token, Room Full).
    - Provide user-friendly diagnostics when reconnection attempts fail.
- **Verification**: Run audio room join and video live streaming tests on emulator or physical device.

---

## Verification & Cutover Checklist

### 1. Backend Server Readiness
- [ ] Token server responds `200 OK` on `GET /health`.
- [ ] Token server generates valid signed JWT on `POST /token`.
- [ ] LiveKit SFU WebSocket handshake succeeds on `/` or `:7880`.

### 2. Live Media Verification
- [ ] Audio Party Room: Host and guest join, speak on mic seats; audio streams publish and subscribe with low latency (<300ms).
- [ ] Video Live Room: Host publishes camera video; audience view receives video feed.
- [ ] 1v1 PK Battle: Dual-room connection to LiveKit properly publishes video tracks side-by-side.

### 3. Production Cutover
- [ ] Update Firestore document `appSettings/livekit_config`.
- [ ] Verify client logs confirm:
  ```text
  [AppConfig] LiveKit URL set to: <NEW_URL>
  [AppConfig] Token Server URL set to: <NEW_URL>
  ```
