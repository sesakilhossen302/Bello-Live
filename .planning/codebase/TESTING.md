# Testing Patterns

**Analysis Date:** 2026-09-21

## Test Framework

**Runner:**
- `flutter_test` (Flutter SDK built-in test runner)
- SDK Constraint: `^3.9.0` (`pubspec.yaml`)

**Assertion Library:**
- Flutter Test Matchers (`expect`, `findsOneWidget`, `findsNothing`, `equals`)

**Run Commands:**
```bash
flutter test                           # Run all test suites
flutter test test/widget_test.dart      # Run specific test file
flutter test --coverage                # Generate LCOV coverage report (coverage/lcov.info)
```

## Test File Organization

**Location:**
- Test files reside in the dedicated root `test/` directory.

**Naming:**
- Follows standard Dart convention with `*_test.dart` suffix.
- Example: `test/widget_test.dart`.

**Structure:**
```
test/
└── widget_test.dart                   # Smoke test template (currently commented out)
```

## Test Structure

**Suite Organization:**
When tests are active, test cases are organized using Flutter's `testWidgets` or standard `test()` suites:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:picture_live/main.dart';

void main() {
  group('Smoke Tests', () {
    testWidgets('App initializes and boots MyApp', (WidgetTester tester) async {
      // await tester.pumpWidget(const MyApp());
      // expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
```

## Mocking

**Framework:**
- No external mocking library (`mockito` or `mocktail`) is currently included in `dev_dependencies` in `pubspec.yaml`.

**What Needs Mocking for Unit Testing:**
- Firebase Services: `FirebaseFirestore`, `FirebaseDatabase`, `FirebaseAuth`, `FirebaseStorage`.
- Real-Time Communication: `LiveKitService` WebRTC sockets and token servers.
- Platform Channels: `FlutterSecureStorage`, `FlutterUdid`, `DeviceCapabilities`.

## Fixtures and Factories

**Test Data:**
- Mock data factories should be created for:
  - Mock `User` profiles (with balance, VIP level, bag items).
  - Mock RTDB room snapshots (participant seat mappings, mute states).
  - Mock LiveKit JWT tokens and chat messages (`LiveKitChatMessage`).

## Coverage

**Requirements:**
- None currently enforced by CI/CD or git hooks.
- Coverage can be collected locally:
  ```bash
  flutter test --coverage
  ```

## Test Types

**Unit Tests:**
- Target domain logic and math algorithms without UI dependencies:
  - `LevelService`: XP progression, diamond threshold tiers, and fallback bracket calculations (`lib/data/remote/firebase/level_service.dart`).
  - `AppCubit`: State transitions for room minimization, language change, and version flags (`lib/core/cubits/app_cubit.dart`).
  - LiveKit token parsing and URL formation (`lib/core/services/livekit_service.dart`).

**Widget Tests:**
- Verify isolated UI components:
  - `FloatingMinimizedRoom`: Draggable behavior and mute indicators (`lib/ui/widgets/floating_minimized_room.dart`).
  - `GlobalGiftBanner`: Ticker visibility and auto-dismiss timing (`lib/ui/widgets/global_gift_banner.dart`).
  - Seat layout widgets in audio room (`lib/ui/streaming/widgets/`).

**Integration / E2E Tests:**
- Real-time WebRTC media streams and Firebase network sync require device-level staging environments with real hardware microphones and cameras.

## Common Patterns

**Async Testing:**
```dart
test('LiveKit token request payload format', () async {
  // Use Fake/Mock HTTP client
});
```

**Widget Pumping:**
```dart
testWidgets('Renders global overlays', (tester) async {
  // Pump widget with mock BlocProvider
});
```

---

*Testing analysis: 2026-09-21*
