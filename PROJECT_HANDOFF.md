# all_one — project handoff

Last updated: 2026-09-16 (Asia/Ho_Chi_Minh)

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
  → white PIN-header loading state with certificate-specific badge animation
  → screen 8: six-digit PIN
  → dimmed certificate/Home transition with original loading animation
  → Home
```

- `lib/main.dart` initializes status-bar styling, locks portrait orientation, initializes `AuthService` and user data, then opens `SplashScreen`.
- iOS native launch uses screen 6 artwork through `ios/Runner/Base.lproj/LaunchScreen.storyboard` and `LaunchImage.imageset`.
- Android 12+ necessarily shows the system splash with the app icon first; Flutter screen 6 follows it. Do not try to remove the Android 12 system splash.
- Screen 6 is implemented by `SplashScreen` with `assets/images/entry_6_splash.png`.
- Screen 7 is implemented by `CertificateLoginScreen` with `assets/images/entry_7_certificate.png`. It continues automatically after 750 ms; the visible Login button has no tap target. Opening an alternate-login sheet cancels the automatic timer.
- Screen 8 is implemented by `PinScreen` with `assets/images/entry_8_pin.png` plus native interactive PIN dots/keypad. When entered from screen 7, it first shows the reference header with the certificate-specific badge APNG for 600 ms, then reveals the dots and keypad. The top-right close `X` and its action are intentionally removed.
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

- The certificate→PIN and PIN→Home loaders are intentionally different assets; do not substitute one for the other or recreate either with a painter.
- `assets/images/loading_certificate_to_pin.png` is a 288×288, 36-frame APNG running at the source video's 59.975 fps for about 600 ms. It applies frame-by-frame image-registration transforms measured from `video_2026-09-12_15-24-41.mp4` to the sharp, clean-edged badge, preserving the subtle twist/scale movement without restoring the earlier blur or dark outline. `PinScreen` displays it at 72 logical pixels; this applies the measured 0.85 size ratio between the supplied references (`2.jpg`: 102 px, `1.jpg`: 120 px).
- The certificate loader reproduces the source cadence: visible from source time 1.550–1.667 s, blank for one frame at 1.683 s, visible at 1.700–1.717 s, blank for one frame at 1.733 s, visible again from 1.750–1.883 s, then blank through the end of the 600-ms transition.
- `assets/images/loading_original.png` is the separate transparent 288×288 APNG extracted directly from `mockup/9.mp4`. It contains 20 frames at 50 ms per frame and loops continuously. The source crop was upscaled with high-quality interpolation and the uniform video background was removed.
- `lib/ui/app_loading_transition.dart` displays `loading_original.png` at 84 logical pixels over a `0x73000000` scrim.
- The transition holds on the certificate screen, reveals Home underneath, and then fades to Home.
- The animated asset has been confirmed running on Samsung SM-A366B. Keep `gaplessPlayback` and high filter quality.

## App identity and artwork

- Canonical app-logo source: `assets/images/brand_logo.png` (1024×1024 RGBA).
- The `all one NH` lettering inside the green app logo is white, not black. This applies to launcher icons and splash artwork.
- Android adaptive icon resources are under `android/app/src/main/res/`; iOS app icons are under `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Home reference icons are the sharp `ref_*` assets under `assets/images/`, including shortcuts, spending, assets, group cards, and bottom navigation. Prefer these over approximate Material icons.
- The Home bottom navigation has rounded upper side edges matching the mockups; inactive labels are intentionally darker than the earliest implementation.
- Scratch frames, crops, contact sheets, and screenshots belong in `/tmp`, not in the repository. Do not delete production reference assets merely because they were derived from mockups.
- `assets/images/transaction_tlj_cakes.jpg` is the sharp 2× TLJ cake artwork extracted from the transaction-history reference and displayed inside a native Flutter banner.

## Home state and completed visual fixes

- `lib/ui/home_screen.dart` owns Home interaction state; `lib/ui/native_home_view.dart` owns the visual layout.
- The header, event banner, finance tabs/account card, 40% banner, benefits, shortcuts, group banner, spending/assets sections, lifestyle cards, NH group grid, fixed bottom navigation, and floating asset button reproduce mockups 1–5.
- Header globe, bell, search, and large-text toggle are aligned with the login/name row.
- Muted Home copy was made slightly darker/larger while preserving the established typography scale.
- The daily-benefit hand/coin row and purple group banner artwork use mockup-derived assets.
- Large text uses a `1.13` multiplier over the normal Home text scale. The account card grows from 326 to 342 design pixels in large-text mode so the three action buttons do not overflow.
- Header and bottom navigation remain fixed while Home content scrolls. Header search jumps to the benefits section.
- Amount visibility, NH/other-finance tabs, account-number copy, account details, transfer flow, and data-management screens are wired.
- The Home account logo is a 48×48 blue rounded square. Shared `BankLogo` now places every bank/security mark on an opaque brand-color rounded-square tile throughout account, recipient, picker, and transfer screens; Toss Bank/Securities reuse the transparent Toss mark in white on the common Toss-blue tile.
- The Home `한도해제` action has its own route to `lib/ui/limit_release_screen.dart`; `거래내역` continues to open the existing account-details flow.
- `LimitReleaseScreen` reproduces the supplied top and scrolled reference states as one continuous 588×1280 scrollable page. Its back/title/home/search header remains fixed, while the current primary account (or the reference fallback account) and the Korean guidance copy scroll underneath it.
- The Home `거래내역` action opens `AccountDetailsScreen`, now matching the supplied `거래내역조회` top and scrolled mockups. The page keeps its header and account identity fixed, scrolls away the balance/actions/TLJ banner, pins the one-month filter beneath the account identity, and renders current ledger entries as dated deposit/withdrawal rows with running balances.
- The Home `이체` action opens `TransferRecipientScreen` directly on the account-number/bank entry view. That view reproduces the supplied recipient mockup with back/cancel controls, disabled Next state, four recipient tabs, and the empty recent-transfer state; account numbers use a digits-only system keyboard rather than the former permanently visible custom keypad.
- The bank/security picker is one continuous bottom-sheet route. Its title and close button remain fixed while the segmented control and two-column institution list scroll together. The bank tab follows the supplied row order through `지방세입`; the securities tab follows the supplied 24-entry order.
- Picker logos reuse the sharp 1024×1024 sources already imported from the sibling `app_hq/bank_icons` directory (52 of the current 56 logo assets are byte-identical to those source files). `BankLogo` sizes them through layout constraints instead of an extra transform/raster-cache layer, clips the final tile rather than the transparent/circular source silhouette, and supplies an institution-specific background color so the visible outer shape matches the rounded-square reference treatment.
- Secondary copy on the limit-release, transaction-history, transfer-recipient, and institution-picker screens uses the darker Home muted tone (`#62696B`) with medium/semibold rendering so it remains legible on physical Android devices.
- Transaction-history type labels (`입금`/`출금`) above the right-aligned amounts use semibold text so they remain clear on physical Android displays.
- The three data-management tabs keep their content inside the bottom system safe area, so account/recipient action buttons and the lowest list content stay above Android's three-button or gesture navigation bar.
- Transfer-flow accents use the shared All One green (`#159757`) across recipient entry, review, PIN indicators/keypad, and the failure-popup action. Amount and review bottom actions respect Android's system inset; amount-keypad digits use medium (`w500`) while the white PIN digits use bold (`w700`).

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
- Widget coverage includes entry 6, white certificate status bar, automatic 7→PIN loading→8→loading→Home, absence of the certificate Login tap target and PIN close control, PIN shuffle/dot alignment, fixed Home chrome, large-text account-card bounds, the rounded-square Home account logo, limit-release/transaction-history/transfer routing, the fixed bank-picker title and scroll behavior, bank/security tab switching, and Korean login/register sheets.
- Loading tests validate the separate APNGs: certificate→PIN is 36 frames using a repeating 17/17/16-ms cadence for an exact 600-ms total, and PIN→Home is 20 frames at 50 ms per frame; both are 288×288.
- Latest verification after the certificate/PIN transition correction on 2026-09-12:
  - `flutter analyze`: no issues.
  - `flutter test test/widget_test.dart`: 12 passed.
  - `flutter test test/preview_golden_test.dart`: 2 passed.
- Latest verification after reproducing the source-video certificate-loader motion on 2026-09-12:
  - `flutter analyze`: no issues.
  - `flutter test test/widget_test.dart`: 12 passed, including checks for all 36 frame durations, the exact blink-frame pattern, the 600-ms total, and the 72×72 logical-pixel loader size.
  - `flutter test test/preview_golden_test.dart`: 2 passed.
- Platform verification after the certificate/PIN transition correction on 2026-09-12:
  - The current Android debug APK with the sharpened, clean-edged, source-motion certificate loader and removed PIN close control built, installed, and launched successfully on Samsung SM-A366B over wireless ADB.
  - The first frame rendered with no Dart/Flutter exception during launch. Flutter detached while leaving the app process running for manual visual verification.
  - An earlier smoke test on the same device covered the white certificate status bar, large-text Home without overflow, loading animation, and navigation to Home.
- Xcode Cloud/TestFlight build repair verification on 2026-09-13:
  - A simulated clean checkout ran `ios/ci_scripts/ci_post_clone.sh` successfully and generated Flutter plus CocoaPods release configuration files before archive.
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 full `flutter test`: 35 passed.
  - Flutter 3.38.10 unsigned release archive succeeded for `com.nhallone.allOne` version 1.0.0 build 1 and produced an arm64 `Runner.xcarchive`.
- Latest verification after the Home logo and limit-release screen work on 2026-09-14:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart`: 13 passed.
  - Flutter 3.38.10 `flutter test test/preview_golden_test.dart`: 3 passed, including top and scrolled limit-release checkpoints.
- Latest verification after the transaction-history visual update on 2026-09-14:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart`: 14 passed.
  - Flutter 3.38.10 `flutter test test/preview_golden_test.dart`: 4 passed, including top and scrolled transaction-history checkpoints.
  - Flutter 3.38.10 `flutter build apk --debug`: succeeded; the SDK's attempted `minSdk` normalization was intentionally reverted to preserve the repository's explicit Android API 23 contract.
- Latest verification after the transfer-recipient and institution-picker update on 2026-09-14:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart test/bank_catalog_test.dart`: 17 passed.
  - Flutter 3.38.10 `flutter test test/preview_golden_test.dart`: 5 passed, including recipient entry, bank-picker top/scrolled, and securities-picker checkpoints.
  - Flutter 3.38.10 `flutter build apk --debug`: succeeded; the SDK's automatic `minSdk` rewrite was reverted again so the explicit Android API 23 contract remains unchanged.
- Latest verification after the shared logo-corner and muted-copy polish on 2026-09-14:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart test/bank_catalog_test.dart test/preview_golden_test.dart`: 22 passed.
  - Golden checkpoints were regenerated for the intentional visual change and reviewed across Home, limit release, transaction history, transfer recipient, bank picker, and securities picker.
- Latest verification after the Android data-management safe-area fix on 2026-09-15:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/data_management_screen_test.dart`: 1 passed, covering the account and recipient bottom actions with a 68-pixel system navigation inset.
  - The debug APK built, installed, and launched successfully on Samsung SM-A366B (Android 16/API 36); Flutter's automatic `minSdk` rewrite was reverted to preserve API 23.
- Latest verification after the transaction-history type-label weight adjustment on 2026-09-15:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart`: 15 passed.
- Latest verification after the transfer amount-screen Android safe-area and keypad-weight fix on 2026-09-15:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart`: 16 passed, including the 68-pixel Android navigation-inset layout assertion and keypad weight check.
  - The debug APK built, installed, and launched successfully on Samsung SM-A366B; Flutter's automatic `minSdk` rewrite was reverted to preserve API 23.
- Latest verification after the transfer-flow green-accent and review safe-area update on 2026-09-15:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/widget_test.dart`: 16 passed, including green accents, amount/review Android safe areas, bold PIN digits, and failure-popup action color.
  - Flutter 3.38.10 transfer-recipient/institution-picker golden test: 1 test passed across four checkpoints.
  - Transaction-history top/scrolled golden baselines were updated after visual review to record the prior intentional `입금`/`출금` weight change.
  - Flutter 3.38.10 `flutter test --concurrency=1`: 43 passed; serial execution avoids a transient golden-artifact race observed when test files run in parallel.
  - The debug APK built, installed, and launched successfully on Samsung SM-A366B; Flutter's automatic `minSdk` rewrite was reverted to preserve API 23.
- Latest verification after the transfer-recipient field fidelity correction on 2026-09-16:
  - The account-number field now paints at the same 79-design-pixel height as the bank selector, with vertically centered content; the `은행을 선택해 주세요` label uses `w700` like the reference app.
  - The recipient golden checkpoint was intentionally regenerated and visually compared with the supplied original reference.
  - The debug APK built, installed, and launched successfully on the Samsung SM-A366B; Flutter was detached with the app still foregrounded. The build tool's automatic `minSdk` rewrite was reverted to preserve Android API 23.
- Latest verification after the app-wide rounded-square institution-logo update on 2026-09-16:
  - Flutter 3.38.10 `flutter analyze`: no issues.
  - Flutter 3.38.10 `flutter test test/bank_catalog_test.dart test/widget_test.dart`: 20 passed, including exhaustive opaque tile-color coverage and shared rounded-corner assertions.
  - Flutter 3.38.10 recipient/institution-picker golden test: 1 test passed across four checkpoints after intentionally regenerating and visually reviewing the recipient, bank-picker top/scrolled, and securities-picker baselines.
  - Public third-party Korean financial-logo sets were evaluated but not added: they reproduce general institution marks, not the proprietary NH All One tile artwork, and would add a new SVG dependency without guaranteeing pixel-identical output.
- Latest Android Studio/Flutter Gradle compatibility repair on 2026-09-16:
  - `android/gradle/wrapper/gradle-wrapper.properties` uses Gradle 8.14 and `android/settings.gradle.kts` uses Android Gradle Plugin 8.11.1, the Flutter 3.38 template-compatible pair. Do not use `--android-skip-build-dependency-validation` as a workaround.
  - Flutter 3.38.10 `flutter build apk --debug` succeeded and produced `build/app/outputs/flutter-apk/app-debug.apk`.
  - Flutter 3.38.10 `flutter analyze`: no issues.
- Release verification on 2026-09-16:
  - Flutter 3.38.10 `flutter build apk --release` succeeded and produced `build/app/outputs/flutter-apk/app-release.apk` (99.4 MB).
  - Flutter's Gradle migration temporarily rewrites the explicit Android API 23 `minSdk`; restore `minSdk = 23` in the tracked `android/app/build.gradle.kts` after any local build.
- Xcode Cloud iOS deployment-target repair on 2026-09-16:
  - The Xcode Cloud archive reported 20 pods and privacy bundles with iOS deployment targets from 9.0 through 13.0, while the Cloud Xcode image accepts iOS 15.0 or later.
  - `ios/Podfile` now raises every generated Pods build configuration to iOS 15.0 after Flutter's standard CocoaPods settings are applied. `pod install` completed and the generated Pods project has no remaining 9.0–14.0 deployment targets.

## Known limits and next-session checklist

- This workspace may not be a Git worktree. If `git status` returns no repository, do not assume version history is available.
- Release Android currently uses the debug signing configuration. Do not treat the current APK as production-signed.
- Xcode Cloud requires `ios/ci_scripts/ci_post_clone.sh`. A clean checkout does not contain the ignored `ios/Flutter/Generated.xcconfig`; the post-clone script installs pinned Flutter 3.38.10, fetches iOS artifacts and Dart packages, installs CocoaPods when needed, runs `pod install`, and verifies all generated release configuration files before Xcode archives `Runner.xcworkspace`. Keep Flutter at 3.38 or newer because current Firebase plugins use the iOS scene lifecycle API introduced in Flutter 3.38.
- iOS minimum deployment target is 15.0. Build/smoke-test iOS when an iPhone or suitable simulator is available, especially after native launch/status-bar changes.
- At the start of any new task: read `AGENTS.md` and this file, inspect status, locate the exact widget/symbol, preserve unrelated edits, then run the narrowest relevant test before expanding verification.
