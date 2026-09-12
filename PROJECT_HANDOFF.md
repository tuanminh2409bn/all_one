# all_one — project handoff

Last updated: 2026-09-12 (Asia/Ho_Chi_Minh)

This is the persistent starting context for a new development session. Read it after `AGENTS.md`. It records the current state and decisions; source code remains authoritative if the two differ.

## Product and visual contract

- Flutter recreation of NH올원뱅크. Dart constraint: `^3.8.1`.
- Keep all Korean product copy intact unless the user explicitly changes it.
- Home is a native Flutter layout based on a fixed 588×1280 reference canvas and mockups `mockup/1.jpg` through `mockup/5.jpg`.
- Entry screens reproduce `mockup/6.jpg`, `mockup/7.jpg`, and `mockup/8.jpg`. The original loading reference is `mockup/9.mp4`.
- UI artwork extracted from a mockup is a production asset. Do not regenerate, rescale, replace, or delete it without comparing against its source mockup.
- Important UI files can be very large. Search for the target class/key first and open only the affected range, especially in `native_home_view.dart`, `account_details_screen.dart`, and `transfer_recipient_screen.dart`.

## Current launch and authentication flow

```text
Native platform launch
  → screen 6: campaign splash
  → screen 7: NH certificate login
  → screen 8: six-digit PIN
  → dimmed certificate/Home transition with original loading animation
  → Home
```

- `lib/main.dart` initializes status-bar styling, locks portrait orientation, initializes `AuthService` and user data, then opens `SplashScreen`.
- iOS native launch uses screen 6 artwork through `ios/Runner/Base.lproj/LaunchScreen.storyboard` and `LaunchImage.imageset`.
- Android 12+ necessarily shows the system splash with the app icon first; Flutter screen 6 follows it. Do not try to remove the Android 12 system splash.
- Screen 6 is implemented by `SplashScreen` with `assets/images/entry_6_splash.png`.
- Screen 7 is implemented by `CertificateLoginScreen` with `assets/images/entry_7_certificate.png` and invisible semantic tap targets aligned to the reference.
- Screen 8 is implemented by `PinScreen` with `assets/images/entry_8_pin.png` plus native interactive PIN dots/keypad.
- The certificate screen has an explicit white safe-area overlay (`certificate-status-bar-background`). This is required because Android edge-to-edge may ignore only setting `statusBarColor`; the same safe-area mechanism also covers iOS status bars/notches.
- Android status-bar behavior has been checked on a Samsung SM-A366B. The iOS code path is shared and structurally covered, but this final status-bar change has not been smoke-tested on a physical iPhone.

## PIN behavior and security

- Initial keypad order matches mockup 8: `4, 7, 2 / 6, 8, 5 / 3, 9, 0 / 1`.
- The shuffle control changes the digit order while keeping the original bold, sharp digit artwork.
- Entered green dots are aligned exactly over the six outlined reference dots.
- Guests use the legacy visual flow. Signed-in users create/confirm or verify their own PIN.
- PIN values are handled by `lib/core/pin_security.dart` and stored with `flutter_secure_storage`; never log or document PIN values.
- Failed verification locks on the fifth wrong attempt. Reset requires Firebase reauthentication.
- Preserve account- and purpose-scoped PIN isolation and the tests in `test/pin_security_test.dart`.

## Loading transition

- Do not recreate the loading logo with a painter or a generic rotation.
- `assets/images/loading_original.png` is a transparent 288×288 APNG extracted directly from `mockup/9.mp4`.
- It contains 20 frames at 50 ms per frame and loops continuously. The source crop was upscaled with high-quality interpolation and the uniform video background was removed.
- `lib/ui/app_loading_transition.dart` displays it at 84 logical pixels over a `0x73000000` scrim.
- The transition holds on the certificate screen, reveals Home underneath, and then fades to Home.
- The animated asset has been confirmed running on Samsung SM-A366B. Keep `gaplessPlayback` and high filter quality.

## App identity and artwork

- Canonical app-logo source: `assets/images/brand_logo.png` (1024×1024 RGBA).
- The `all one NH` lettering inside the green app logo is white, not black. This applies to launcher icons and splash artwork.
- Android adaptive icon resources are under `android/app/src/main/res/`; iOS app icons are under `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Home reference icons are the sharp `ref_*` assets under `assets/images/`, including shortcuts, spending, assets, group cards, and bottom navigation. Prefer these over approximate Material icons.
- The Home bottom navigation has rounded upper side edges matching the mockups; inactive labels are intentionally darker than the earliest implementation.
- Scratch frames, crops, contact sheets, and screenshots belong in `/tmp`, not in the repository. Do not delete production reference assets merely because they were derived from mockups.

## Home state and completed visual fixes

- `lib/ui/home_screen.dart` owns Home interaction state; `lib/ui/native_home_view.dart` owns the visual layout.
- The header, event banner, finance tabs/account card, 40% banner, benefits, shortcuts, group banner, spending/assets sections, lifestyle cards, NH group grid, fixed bottom navigation, and floating asset button reproduce mockups 1–5.
- Header globe, bell, search, and large-text toggle are aligned with the login/name row.
- Muted Home copy was made slightly darker/larger while preserving the established typography scale.
- The daily-benefit hand/coin row and purple group banner artwork use mockup-derived assets.
- Large text uses a `1.13` multiplier over the normal Home text scale. The account card grows from 326 to 342 design pixels in large-text mode so the three action buttons do not overflow.
- Header and bottom navigation remain fixed while Home content scrolls. Header search jumps to the benefits section.
- Amount visibility, NH/other-finance tabs, account-number copy, account details, transfer flow, and data-management screens are wired.

## Data architecture

- `lib/core/auth_service.dart`: Firebase Email/Password authentication with a debug-only local fallback. The fallback stores a password digest, never clear text.
- `lib/core/app_data.dart`: accounts, transactions, recipients, balances, Home display values, local persistence, and cloud synchronization.
- `SharedPreferences` is the immediate offline source. Signed-in Firebase users sync one state document at `users/{uid}/app_data/state` in Firestore.
- Current data schema is version 2. It removes old mockup records during legacy migration while retaining user-created data.
- Each new user scope starts with an empty live ledger; mock data is only for isolated tests.
- Saved recipient limit is 50. Account-number comparison normalizes to digits while retaining display formatting.
- Keep data/auth/PIN/bootstrap logic in `lib/core/`; do not move it into widgets.

## Firebase configuration

- Firebase project: `all-one-fa936`; project number: `23011584622`.
- Android app ID: `1:23011584622:android:a304e9bb023a025bb9d47f`; package: `com.nhallone.all_one`.
- iOS app ID: `1:23011584622:ios:32b949aa35556074b9d47f`; bundle ID: `com.nhallone.allOne`.
- Local files:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- On 2026-09-12, Firebase CLI 15.24.0 downloaded the current SDK configs for both ACTIVE apps. A parsed full-content comparison found both local files semantically identical to Firebase. Raw bytes differ only because Firebase emits different whitespace/key ordering.
- Do not print API keys or copy complete config contents into logs/docs. To recheck safely, download each config to `/tmp`, parse JSON/plist, and compare all fields rather than relying on a byte hash.
- Email/Password authentication must be enabled in Firebase Console. Firestore rules live in `firestore.rules`; deployment is not implied by local edits.

## Tests and verification

Relevant commands:

```sh
flutter analyze
flutter test test/widget_test.dart
flutter test test/preview_golden_test.dart
flutter test test/pin_security_test.dart
flutter test test/app_data_test.dart test/persistence_test.dart
flutter test test/bank_catalog_test.dart
flutter build apk --debug
```

- Format only changed Dart files with `dart format <files>`.
- Golden tests use the intentional current visual baseline. Never update goldens just to silence a mismatch.
- Widget coverage includes entry 6, white certificate status bar, 7→8→loading→Home, PIN close/shuffle/dot alignment, fixed Home chrome, large-text account-card bounds, and Korean login/register sheets.
- The loading test validates the APNG as 20 frames, 50 ms first-frame duration, 288×288.
- Latest verification on 2026-09-12:
  - `flutter analyze`: no issues.
  - `flutter test test/widget_test.dart`: 11 passed.
  - `flutter test test/preview_golden_test.dart`: 2 passed.
  - Android debug APK built successfully.
  - Samsung SM-A366B smoke test: white certificate status bar, large-text Home without overflow, loading animation, navigation to Home, and no Flutter/Android runtime errors.

## Known limits and next-session checklist

- This workspace may not be a Git worktree. If `git status` returns no repository, do not assume version history is available.
- Release Android currently uses the debug signing configuration. Do not treat the current APK as production-signed.
- iOS minimum deployment target is 15.0. Build/smoke-test iOS when an iPhone or suitable simulator is available, especially after native launch/status-bar changes.
- At the start of any new task: read `AGENTS.md` and this file, inspect status, locate the exact widget/symbol, preserve unrelated edits, then run the narrowest relevant test before expanding verification.
