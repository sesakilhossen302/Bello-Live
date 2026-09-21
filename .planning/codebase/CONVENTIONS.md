# Coding Conventions

**Analysis Date:** 2026-09-21

## Naming Patterns

**Files:**
- Use lowercase `snake_case.dart` for all file names.
- Apply descriptive suffixes denoting architectural role:
  - `_page.dart`: Full-screen UI route (e.g. `lib/ui/streaming/audio_room_page.dart`)
  - `_bottomsheet.dart`: Modal or bottom sheet component (e.g. `lib/ui/streaming/bottomsheets/gifts_bottomsheet.dart`)
  - `_service.dart` / `_services.dart`: Backend or API communication layer (e.g. `lib/data/remote/firebase/room_services.dart`)
  - `_cubit.dart`: BLoC state manager (e.g. `lib/core/cubits/app_cubit.dart`)
  - `_state.dart`: Immutable state definition (e.g. `lib/core/cubits/app_state.dart`)
  - `_widget.dart`: Reusable UI widget (e.g. `lib/core/widgets/active_frame_widget.dart`)

**Functions & Methods:**
- Use `lowerCamelCase` (e.g. `fetchToken()`, `connectRoom()`, `turnMicrophoneOn()`).
- Private methods and internal handlers are prefixed with an underscore (e.g. `_initListeners()`, `_showGiftOverlay()`).

**Variables & Fields:**
- Use `lowerCamelCase` for local variables and class fields (e.g. `roomName`, `isHost`).
- Private class members and controllers must be prefixed with `_` (e.g. `_room`, `_isSpeakerMuted`, `_activeSpeakersController`).

**Types & Enums:**
- Use `UpperCamelCase` (PascalCase) for classes, mixins, and enums (e.g. `LiveKitService`, `AppCubit`, `Routes`).
- Enum values use `lowerCamelCase` (e.g. `Routes.audioRoom`, `Routes.liveStream`).

## Code Style

**Formatting:**
- Dart standard formatting enforced via `dart format`.
- Trailing commas preferred on multi-line parameter lists and widget trees to preserve clean indentation.

**Linting:**
- Configured via `analysis_options.yaml` extending `package:flutter_lints/flutter.yaml`.
- Enforces Flutter best practices: `prefer_const_constructors`, `avoid_unnecessary_containers`, `prefer_is_empty`.

## Import Organization

**Order:**
1. Dart core libraries (`dart:async`, `dart:convert`, `dart:io`)
2. Flutter SDK packages (`package:flutter/material.dart`, `package:flutter_bloc/flutter_bloc.dart`)
3. Third-party packages (`package:livekit_client/livekit_client.dart`, `package:cloud_firestore/cloud_firestore.dart`)
4. Internal project package imports (`package:picture_live/...`) or relative imports (`../../core/services/...`)

**Path Aliases:**
- Prefix package imports using `package:picture_live/` for cross-feature access.
- Relative imports (`../`) are commonly used for intra-directory and parent navigation.

## Error Handling

**Patterns:**
- Asynchronous API and SDK invocations are wrapped in explicit `try-catch` blocks:
  ```dart
  try {
    final response = await http.post(url, headers: headers, body: payload);
    // process response
  } catch (e) {
    debugPrint('[Service] Operation failed: $e');
    throw Exception('Descriptive failure: $e');
  }
  ```
- Firestore atomic operations utilize `runTransaction()` to safely handle concurrency conflicts.
- Async context rule: Guard all UI callbacks after `await` with `if (!mounted) return;` before referencing `BuildContext` or `Navigator`.

## Logging

**Framework:**
- Flutter's native `debugPrint()` is used throughout the codebase.

**Patterns:**
- Log statements use tagged square-bracket prefixes to trace subsystems:
  - `debugPrint('[LiveKitService] Connecting to room: $roomName');`
  - `debugPrint('[AppConfig] Token Server URL set to: $tokenServerUrl');`
  - `debugPrint('[HomeBannerCacheService] Cached banners loaded: ${list.length}');`

## Comments

**When to Comment:**
- Document non-obvious architecture constraints (e.g. why a token must be fetched before room joining, or why an RTDB transaction requires detached disconnect listeners).
- Section headers using block comments for major operational areas:
  ```dart
  // ============================================================================
  // TOKEN FETCHING
  // ============================================================================
  ```

**DartDoc:**
- Three-slash comments (`///`) are used for public service APIs and contract methods:
  ```dart
  /// Connects to a LiveKit room with carrier-grade media options.
  Future<Room> connectRoom(...)
  ```

## Function Design

**Size:**
- Service methods are focused and task-oriented (20-60 lines).
- UI build methods in large pages currently suffer from extreme length and should be decomposed into dedicated private helper widgets or smaller component classes.

**Parameters:**
- Methods accepting multiple configurations must use named parameters with `required` annotations:
  ```dart
  Future<String> fetchToken({
    required String roomName,
    required String userId,
    required String userName,
    required String role,
    bool isVideo = false,
  })
  ```

**Return Values:**
- Always explicitly type return values (`Future<void>`, `Future<String>`, `Stream<List<String>>`). Avoid `dynamic` return types.

## Module Design

**Exports:**
- Services expose static accessors or singleton instances (e.g. `LiveKitService.instance`, `AppServices.getLiveKitConfig()`).
- BLoCs and Cubits expose immutable state streams (`AppState`) via `BlocBuilder` and `BlocProvider`.

---

*Convention analysis: 2026-09-21*
