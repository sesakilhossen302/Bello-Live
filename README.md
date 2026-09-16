# SB Live (FlowLive) — Interactive Streaming Platform

Welcome to the **SB Live** (`picture_live` / `FlowLive`) mobile application codebase. This project is a production Flutter application providing real-time audio party rooms, live video streaming with 1v1 PK battles, a virtual gifting economy, and an agency/reseller ecosystem.

---

## 📚 Master Architecture & Technical Documentation

For a comprehensive technical deep dive into the application's architecture, communication layer (**ZEGOCLOUD** / **LiveKit**), database partitioning, seat allocation mechanics, and state management, refer to the master manual:

👉 **[Master Architecture & System Engineering Manual](ARCHITECTURE_AND_SYSTEM_MANUAL.md)**

---

## 🚀 Key Technology Stack

- **Framework**: [Flutter](https://flutter.dev) (SDK `^3.9.0`)
- **Target OS**: Android (`minSdk 21`, `targetSdk 34`, MultiDex & Desugaring enabled) & iOS
- **Real-Time Communications (RTC)**: 
  - Primary: [ZEGOCLOUD](https://www.zegocloud.com) (`zego_uikit`, `zego_express_engine`, `zego_uikit_prebuilt_live_audio_room`)
  - Target Migration: [LiveKit SFU](https://livekit.io) (Reference: `../LIVEKIT_ARCHITECTURE_AND_MIGRATION_GUIDE.md` & `../rtc_server`)
- **Backend & Database**:
  - **Firebase Realtime Database (RTDB)**: Ephemeral, ultra-fast signaling (seats, PK state, gifts, presence)
  - **Cloud Firestore**: Persistent storage (user profiles, wallets, store items, reseller transactions, level definitions)
  - **Firebase Auth & FCM**: Authentication & Topic-based Push Notifications
- **State Management & DI**: `flutter_bloc` / Cubit (`AppCubit`), `get_it`, `RxDart`
- **Routing**: `go_router` (`MyRouter` with 52 routes)
- **Rich Media & Visuals**: `flutter_svga` (Hardware-accelerated SVGA animations for gifts and soundwave indicators)

---

## 🛠️ Project Structure Quick Reference

```
lib/
├── core/               # Cubits, localization, shared widgets (SVGA players, frames)
├── data/
│   ├── local/          # Encrypted secure storage
│   └── remote/firebase/# Domain services (AppServices, RoomService, LiveStreamService, etc.)
├── di/                 # Dependency injection (GetIt)
├── navigation/         # GoRouter setup and route definitions
├── theme/              # Material 3 app theme tokens and palettes
└── ui/                 # Feature presentation screens and bottom sheets
    ├── streaming/      # Multi-seat Audio Party Room (audio_room_page.dart)
    ├── live_streaming/ # Video Live Streaming & 1v1 PK Battles (live_room_page.dart)
    ├── reseller/       # Coin reseller distribution hub & transactions
    ├── store-bag/      # Virtual cosmetic store, skins, frames, vehicles
    └── widgets/        # Floating PIP room, device ban & block listeners
```
