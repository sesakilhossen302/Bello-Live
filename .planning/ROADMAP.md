# Project Roadmap

## Milestone 1: RTC Server Migration, Stabilization & Architecture Modularization

### Phase Overview

```
Phase 1: RTC Communication Backend Migration (Audio & Video)
                                │
                                ▼
Phase 2: Codebase Hygiene & Stability ──────▶ Phase 3: God-Widget Decomposition
                                                        │
                                                        ▼
Phase 5: Media Performance & Security ◀────── Phase 4: Automated Testing & APM
```

---

### Phase 1: RTC Communication Backend Server Migration (Audio & Video) [URGENT - IN PROGRESS]
- **Focus**: Safely migrate the communication backend (LiveKit SFU + Token Server) from the decommissioned/stopped server to the new target server.
- **Goals**:
  - Deploy LiveKit SFU and Node.js Token Server on the new host environment.
  - Set up SSL/TLS (HTTPS/WSS) and firewall/port forwarding (7880, 7881, 7882/udp, 5000/443).
  - Update dynamic Firestore configuration (`appSettings/livekit_config`) for instant seamless cutover without requiring mobile app rebuilds.
  - Update static fallback endpoints in `lib/core/config/app_config.dart`.
  - Add connection health checks, timeout diagnostics, and fallback handling in `LiveKitService`.
- **Requirements Satisfied**: `MIG-01`, `MIG-02`, `MIG-03`, `MIG-04`, `MIG-05`, `MIG-06`
- **Status**: Ready to execute (Plan generated in `phases/01-rtc-server-migration/01-PLAN.md`)

---

### Phase 2: Codebase Hygiene & Stability
- **Focus**: Eliminate critical crash vectors, clear clutter, and align architectural docs.
- **Goals**:
  - Relocate root automation and legacy files into `scripts/legacy/`.
  - Fix all unhandled async context gaps (`use_build_context_synchronously`).
  - Wire up report user submission logic in `report_user_bottomsheet.dart`.
  - Update `ARCHITECTURE_AND_SYSTEM_MANUAL.md` with the new server details.
- **Requirements Satisfied**: `HYG-01`, `HYG-02`, `HYG-03`, `STAB-01`, `STAB-02`
- **Status**: Backlog (depends on Phase 1)

---

### Phase 3: Monolithic God-Widget Decomposition & State Isolation
- **Focus**: Modularize `audio_room_page.dart` (4,851 lines) and `live_room_page.dart` (4,536 lines).
- **Goals**:
  - Extract `AudioRoomCubit`, `SeatGridCubit`, and decompose UI into isolated widgets.
  - Extract `LiveRoomCubit` and `PKBattleStateController`.
  - Implement PK heartbeat/ping timeout safeguards.
- **Requirements Satisfied**: `ARCH-01`, `ARCH-02`, `ARCH-03`, `ARCH-04`, `STAB-03`
- **Status**: Backlog (depends on Phase 2)

---

### Phase 4: Automated Testing & APM Integration
- **Focus**: Establish quality safety net and production error monitoring.
- **Goals**:
  - Set up test mocks and harness.
  - Implement unit test suites for core Cubits and service handlers.
  - Integrate `firebase_crashlytics` into `pubspec.yaml` and entrypoints.
- **Requirements Satisfied**: `TEST-01`, `TEST-02`, `TEST-03`
- **Status**: Backlog (depends on Phase 3)

---

### Phase 5: Media Performance & Security Hardening
- **Focus**: GPU rendering optimization and transaction security.
- **Goals**:
  - Build SVGA concurrency and memory throttle queue.
  - Audit client-side economy transactions and harden Firestore rules.
- **Requirements Satisfied**: `PERF-01`, `SEC-01`
- **Status**: Backlog (depends on Phase 4)
