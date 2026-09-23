# Project: SB Live (FlowLive)

## Executive Summary
**SB Live** (`picture_live` / `FlowLive`) is a production-grade Flutter mobile application delivering real-time interactive experiences:
- Multi-seat audio party rooms.
- Video live streaming with dual-room 1v1 PK battles.
- Real-time virtual gifting economy with animated SVGA effects.
- Coin reseller and agency distribution network.

## Current Baseline Architecture
- **Framework**: Flutter SDK `^3.9.0` (Dart 3.x), targeting Android (API 21-34) and iOS.
- **RTC Engine**: [LiveKit SFU](https://livekit.io) via custom `LiveKitService` and backend token generation.
- **Signaling & State**:
  - **Firebase Realtime Database (RTDB)**: Ultra-low latency signaling for room seats, PK state synchronization, live chat messages, and gift broadcasts.
  - **Cloud Firestore**: Persistent store for user accounts, diamond/coin wallets, reseller logs, VIP frames, and agency management.
  - **Firebase Auth & FCM**: Phone/Google/Apple authentication and push notification topics.
- **State Management & DI**: `flutter_bloc` / Cubit (`AppCubit`), `GetIt` service locator, `RxDart`.
- **Navigation**: `go_router` (`MyRouter`) configured with 52 routes.

## Critical Challenges & Strategic Objectives
1. **Maintainability**: Decompose multi-thousand-line monolithic God-widgets (`audio_room_page.dart` at 4,851 lines and `live_room_page.dart` at 4,536 lines) into modular components and focused Cubits.
2. **Stability**: Eliminate asynchronous context bugs (`use_build_context_synchronously`) cataloged across 90+ locations that risk runtime crashes during stream transitions.
3. **Quality & Confidence**: Establish zero-to-one automated unit and widget test coverage and integrate production crash reporting (Crashlytics/APM).
4. **Performance & Security**: Optimize SVGA GPU animation rendering bursts and secure client-side economy transaction boundaries.
