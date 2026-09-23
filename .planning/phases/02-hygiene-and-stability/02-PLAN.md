# Phase 2 Plan: Codebase Hygiene & Stability

## Phase Objective
Eliminate active runtime crash vectors caused by asynchronous context gaps, implement missing report submission functionality, clean up obsolete root files by archiving them to `scripts/legacy/`, and align architecture documentation with the active LiveKit migration.

## Requirements Covered
- **HYG-01**: Relocate root automation scripts to `scripts/legacy/`.
- **HYG-02**: Archive `old_live_room_page.dart` and `dart_analyze_async.txt`.
- **HYG-03**: Update `ARCHITECTURE_AND_SYSTEM_MANUAL.md` to deprecate ZEGOCLOUD and document LiveKit SFU.
- **STAB-01**: Fix `use_build_context_synchronously` across all screens with `if (!mounted) return;` or state context guards.
- **STAB-02**: Implement user report Firestore write in `report_user_bottomsheet.dart`.

---

## Tasks

### Task 1: Root Cleanup & Script Archiving (HYG-01, HYG-02)
- **Description**: Move legacy files and automation scripts from the project root into `scripts/legacy/` to keep the root clean and prevent developer/tooling confusion.
- **Target Directory**: `scripts/legacy/`
- **Files to Move**:
  - `old_live_room_page.dart`
  - `dart_analyze_async.txt`
  - `replace_print.py`
  - `script.py`
  - `rename_asset.dart`
  - `fix_displayId.dart`
  - `test_youtube.dart`

### Task 2: Implement User Report Logic (STAB-02)
- **Description**: In `lib/ui/live_streaming/bottomsheets/report_user_bottomsheet.dart`, replace `// TODO: Implement actual report logic` with a Firestore document write to the `reports` collection.

### Task 3: Fix Async Context Gaps in Screens (STAB-01)
- **Description**: Review and patch all async context warnings (`use_build_context_synchronously`) across screens.

### Task 4: Synchronize Master Architecture Manual (HYG-03)
- **Description**: Update `ARCHITECTURE_AND_SYSTEM_MANUAL.md` to reflect that LiveKit SFU (`LiveKitService`) is the active production RTC engine.
