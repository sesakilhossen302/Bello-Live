# Codebase Concerns

**Analysis Date:** 2026-09-21

## Tech Debt

**Monolithic God-Widgets:**
- Issue: Live streaming screens are monolithic files containing thousands of lines combining UI, RTDB listeners, WebRTC lifecycle, and modal controllers.
- Files:
  - `lib/ui/streaming/audio_room_page.dart` (4,851 lines)
  - `lib/ui/live_streaming/live_room_page.dart` (4,536 lines)
  - `lib/ui/profile/profile_page.dart` (2,136 lines)
  - `lib/ui/home/home_page.dart` (1,824 lines)
- Impact: Extreme maintenance friction, high likelihood of regressions, inability to write isolated widget tests, and complex state management.
- Fix approach: Extract domain logic into feature Cubits (e.g. `AudioRoomCubit`, `PKBattleCubit`, `SeatGridCubit`) and decompose UI into small, focused sub-widgets.

**Repository Root Clutter & Stray Files:**
- Issue: A legacy backup file and multiple one-off Python and Dart automation scripts reside in the root directory.
- Files:
  - `old_live_room_page.dart` (249 KB legacy file)
  - `dart_analyze_async.txt` (9.4 KB static analyzer log)
  - `replace_print.py`, `script.py`, `rename_asset.dart`, `fix_displayId.dart`, `test_youtube.dart`
- Impact: Confuses new developers and AI tools regarding what is active production code versus obsolete scratch work.
- Fix approach: Archive or delete obsolete root files and relocate necessary migration scripts into a dedicated `scripts/` or `tool/` directory.

**Documentation Drift (Zego vs. LiveKit):**
- Issue: `ARCHITECTURE_AND_SYSTEM_MANUAL.md` still prominently describes ZEGOCLOUD as the active RTC engine, whereas the live codebase has fully migrated to `LiveKitService`.
- Files: `ARCHITECTURE_AND_SYSTEM_MANUAL.md`, `lib/core/services/livekit_service.dart`
- Impact: Architectural confusion for team members and external auditors.
- Fix approach: Update `ARCHITECTURE_AND_SYSTEM_MANUAL.md` to reflect LiveKit as the production media engine.

## Known Bugs

**Async Context Gaps (`use_build_context_synchronously`):**
- Symptoms: Potential runtime exceptions or state corruption when navigating or showing SnackBars after asynchronous network delays.
- Files:
  - `lib/ui/apply/apply_agency.dart` (lines 134, 140, 175, 183, 230)
  - `lib/ui/apply/apply_hosting.dart` (lines 121, 126)
  - `lib/ui/live_streaming/live_room_page.dart` (lines 1029, 1030, 1032, 1293)
  - `lib/ui/profile/edit_profile_page.dart` (lines 100, 138, 144)
  - `lib/ui/status/newsfeed_page.dart` (lines 105, 122)
  - (90+ instances cataloged in `dart_analyze_async.txt`)
- Trigger: User dismisses a dialog or navigates back while a Firestore write or HTTP request is in-flight.
- Workaround: Guard all asynchronous context uses with `if (!mounted) return;` or pass callbacks.

**Unimplemented User Moderation Reporting:**
- Symptoms: Submitting a user report from a live stream performs no actual backend operation.
- Files: `lib/ui/live_streaming/bottomsheets/report_user_bottomsheet.dart` (line 19)
- Trigger: User attempts to report an abusive participant: `// TODO: Implement actual report logic`.
- Fix approach: Implement Firestore document creation in `reports` collection or trigger a Cloud Function.

## Security Considerations

**Unencrypted RTC and Token Endpoints (HTTP / WS):**
- Risk: Cleartext transmission of tokens and media signaling over unencrypted channels (`http://` and `ws://`).
- Files: `lib/core/config/app_config.dart`
- Current mitigation: LiveKit JWT tokens expire after short durations.
- Recommendations: Provision SSL/TLS domain certificates (Let's Encrypt) for `129.212.226.12` and migrate endpoints to `https://` and `wss://`.

**Client-Side Economy Operations:**
- Risk: Direct Firestore writes to `users/{uid}` for coin/diamond balance updates could be exploited if Firestore security rules are permissive.
- Files: `lib/data/remote/firebase/reseller_services.dart`, `lib/data/remote/firebase/profile_services.dart`
- Current mitigation: Transactions used for balance balance transfers.
- Recommendations: Ensure strict server-side Firestore security rules (`firestore.rules`) prevent users from modifying their own `balance` field, enforcing all financial transactions via Cloud Functions.

## Performance Bottlenecks

**Simultaneous SVGA Animation Bursts:**
- Problem: Simultaneous high-tier gifts, soundwave talk rings, and entrance vehicles during active streams cause frame stutter.
- Files: `lib/core/widgets/`, `lib/ui/streaming/audio_room_page.dart`
- Cause: Software decoding and GPU canvas compositing of large SVGA byte arrays.
- Improvement path: Implement an animation queue limiter that caps concurrently playing SVGA players to a maximum of 2, prioritizing higher-value gifts.

**Wide-Tree RTDB Subscriptions:**
- Problem: Excessive data consumption or UI rebuilds if listeners subscribe too high up the tree.
- Files: `lib/data/remote/firebase/room_services.dart`
- Cause: Subscribing to `/rooms/$roomId` rather than specific sub-nodes.
- Improvement path: Ensure listeners strictly target leaf nodes (`/room_participants/$roomId` and `/room_events/$roomId/gift`).

## Fragile Areas

**Dual-Room 1v1 PK Battle State Machine:**
- Files: `lib/ui/live_streaming/live_room_page.dart`, `lib/core/services/livekit_service.dart`
- Why fragile: Requires simultaneous synchronization across two separate WebRTC rooms (`_room` and `_opponentRoom`) alongside RTDB state (`pkState`). If network flickers or one host abruptly terminates, the opposing client may remain stuck in battle mode.
- Safe modification: Encapsulate PK lifecycle into an isolated state controller with automated ping/heartbeat timeouts.
- Test coverage: 0% automated tests.

**In-App Picture-in-Picture (PIP) Handover:**
- Files: `lib/ui/widgets/floating_minimized_room.dart`, `lib/core/cubits/app_cubit.dart`, `lib/main.dart`
- Why fragile: Re-entering a room pushes a new route into `GoRouter` while the old LiveKit session continues running. If teardown order is incorrect, duplicate connections or orphaned audio streams occur.
- Safe modification: Centralize room entry/exit through a dedicated navigation coordinator.

## Scaling Limits

**Single VPS LiveKit Infrastructure:**
- Current capacity: Single Ubuntu VPS (`129.212.226.12`) hosting both LiveKit SFU (Go) and token server (Node.js).
- Limit: ~500-1,000 concurrent video subscribers or ~2,000 audio subscribers per server without clustering.
- Scaling path: Deploy LiveKit SFU cluster behind Redis and a cloud load balancer.

## Dependencies at Risk

**`flutter_svga: ^0.0.6`:**
- Risk: Package is at a very low version (`0.0.6`) and has limited upstream maintenance.
- Impact: Potential rendering incompatibilities with Flutter's Impeller graphics engine on Android and iOS.
- Migration plan: Evaluate modern alternatives such as `lottie` or native Rive animations for future visual effects.

## Missing Critical Features

**APM & Crash Reporting:**
- Problem: Neither Firebase Crashlytics nor Sentry is integrated in `pubspec.yaml`.
- Blocks: Production crash diagnosis in real-time. Unhandled Dart exceptions in production cannot be tracked.

## Test Coverage Gaps

**Zero Automated Test Coverage:**
- What's not tested: Entire codebase lacks unit, widget, and integration tests (`test/widget_test.dart` is commented out).
- Files: `test/widget_test.dart`
- Risk: High probability of introducing undetected regressions when refactoring mega-widgets or updating packages.
- Priority: High

---

*Concerns audit: 2026-09-21*
