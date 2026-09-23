# Project Requirements

## Milestone 1: RTC Server Migration, Stabilization & Architecture Modularization

### Category: RTC Server Migration (MIG) — TOP PRIORITY
- **MIG-01**: Deploy and configure the new LiveKit SFU instance on the target server (Docker / Ubuntu) with audio/video media routing and RTC ports (UDP 7882/UDP, TCP 7881, WebSocket 7880 or WSS 443).
- **MIG-02**: Deploy the Node.js/TypeScript token server (`rtc_server` / token control plane) on the target server, configured with `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, and `/token` endpoint matching the payload expected by `LiveKitService`.
- **MIG-03**: Transition server endpoints to SSL/TLS (HTTPS/WSS) using a domain name and Let's Encrypt / reverse proxy (Nginx/Caddy) to avoid cleartext transmission.
- **MIG-04**: Dynamically switch active client traffic via Firestore `appSettings/livekit_config` (`liveKitUrl` and `tokenServerUrl`), enabling instant migration for existing installed apps without app store re-releases.
- **MIG-05**: Update client-side hardcoded fallbacks in `lib/core/config/app_config.dart` to point to the new production server.
- **MIG-06**: Enhance `LiveKitService` with timeout diagnostics, user-friendly reconnection alerts, and graceful fallback when the communication server is unreachable.

### Category: Codebase Hygiene & Cleanup (HYG)
- **HYG-01**: Clean root directory clutter by relocating automation scripts (`replace_print.py`, `script.py`, `rename_asset.dart`, `fix_displayId.dart`, `test_youtube.dart`) to `scripts/legacy/`.
- **HYG-02**: Archive legacy `old_live_room_page.dart` (249 KB) and temporary log dumps (`dart_analyze_async.txt`).
- **HYG-03**: Update `ARCHITECTURE_AND_SYSTEM_MANUAL.md` to deprecate ZEGOCLOUD and accurately reflect the new LiveKit server setup.

### Category: Runtime Stability & Bug Fixes (STAB)
- **STAB-01**: Guard all post-`await` UI operations with `if (!context.mounted) return;` or state checks across all screens (`apply_agency.dart`, `apply_hosting.dart`, `live_room_page.dart`, `profile_page.dart`, `newsfeed_page.dart`).
- **STAB-02**: Implement missing user moderation report backend logic in `report_user_bottomsheet.dart` (writing to Firestore `reports` collection).
- **STAB-03**: Centralize stream exit and mini-player PIP handover lifecycle to prevent orphaned WebRTC audio/video tracks.

### Category: Modular Architecture (ARCH)
- **ARCH-01**: Extract `AudioRoomCubit` and `SeatGridCubit` from `audio_room_page.dart` (4,851 lines) to handle room seats, mute states, and RTDB subscriptions.
- **ARCH-02**: Decompose `audio_room_page.dart` into discrete UI components (`AudioSeatGrid`, `AudioRoomHeader`, `AudioRoomBottomBar`, `GiftOverlayView`).
- **ARCH-03**: Extract `LiveRoomCubit` and `PKBattleStateController` from `live_room_page.dart` (4,536 lines).
- **ARCH-04**: Implement automated heartbeat timeouts for 1v1 PK battles to prevent hosts from remaining stuck if opponent disconnects unexpectedly.

### Category: Automated Testing & APM (TEST)
- **TEST-01**: Configure Flutter testing environment with mocks for Firebase and LiveKit services.
- **TEST-02**: Write unit test suites for `AppCubit`, `AudioRoomCubit`, and `RoomServices`.
- **TEST-03**: Add `firebase_crashlytics` to `pubspec.yaml` and initialize crash reporting in `main.dart`.

### Category: Media Performance & Security (PERF/SEC)
- **PERF-01**: Implement an SVGA animation queue controller limiting concurrent active hardware-accelerated animations to 2.
- **SEC-01**: Audit Firestore security rules for wallet balance updates and verify financial transaction boundaries.
