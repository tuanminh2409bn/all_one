# all_one project guidance

This file adds project-specific guidance to the global Codex rules. Keep it short and update it only for recurring project facts or mistakes.

## Session bootstrap

- Before changing this repository, read `PROJECT_HANDOFF.md` for the current product flow, implemented features, visual decisions, Firebase state, verification history, and known limitations.
- Update `PROJECT_HANDOFF.md` whenever a completed task changes those facts so a new session can resume without relying on chat history.

## Project contract

- This is a Flutter application using Dart `^3.8.1`.
- Preserve the Korean product copy and the visual fidelity of the 588x1280 reference canvas unless the task explicitly changes them.
- `lib/main.dart` is the entry point.
- Keep data, authentication, PIN, persistence, and bootstrap logic in `lib/core/`.
- Keep screens, widgets, layout, artwork, and painters in `lib/ui/`.
- Follow the existing architecture and dependencies; do not introduce a new state-management, routing, or persistence pattern for a local change.

## Context boundaries

- Search for the target symbol first and open only the relevant ranges.
- Do not read large UI files in full by default, especially `native_home_view.dart`, `account_details_screen.dart`, and `transfer_recipient_screen.dart`.
- Ignore `.dart_tool/`, `build/`, `coverage/`, `ios/Pods/`, `ios/.symlinks/`, `android/.gradle/`, `android/.kotlin/`, IDE files, and generated platform artifacts unless they are directly relevant.
- Inspect assets, mockups, screenshots, or golden images only for visual tasks.
- Do not inspect the body of `pubspec.lock` or edit it manually unless dependency resolution is part of the task.
- Use `tool/trace_tlj.py` only for TLJ artwork tracing work.

## Change boundaries

- Keep business and persistence logic out of widgets when an existing `lib/core/` boundary applies.
- Preserve Firebase Auth, Firestore, SharedPreferences, and secure-storage behavior unless the request explicitly changes it.
- Change `firebase.json`, `firestore.rules`, or platform Firebase configuration only when requested.
- Never print credentials, secrets, PIN values, or persisted user data in logs or reports.
- Refactor large files incrementally around the requested feature; do not perform broad cleanup as part of an unrelated task.
- Do not update golden files merely to make a failing test pass. Update them only for an intentional, reviewed visual change.

## Verification

- Format only changed Dart files with `dart format <files>`.
- Run `flutter analyze` after Dart changes.
- Prefer the narrowest relevant test first:
  - app data or persistence: `flutter test test/app_data_test.dart test/persistence_test.dart`
  - PIN security: `flutter test test/pin_security_test.dart`
  - bank catalog: `flutter test test/bank_catalog_test.dart`
  - widget or navigation behavior: `flutter test test/widget_test.dart`
  - intentional visual changes: `flutter test test/preview_golden_test.dart`
- Run the full `flutter test` suite only for shared, cross-feature, or release-level changes.
- Build or run only the affected platform when static analysis and focused tests cannot prove the result.
