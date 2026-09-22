# all_one — project handoff

Last updated: 2026-09-22 (Asia/Ho_Chi_Minh)

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
- Home's normal typography renders at the reference scale (`1.0`); only the user-controlled large-text mode applies the `1.13` multiplier. Common header, account-card, section, floating-action, and bottom-navigation text bounds were remeasured against the supplied original screenshot.
- Normal copy uses the bundled static `NotoSansKR-Medium.otf` face at `w500`; emphasized copy uses the existing static Bold face. The static Medium face avoids platform-dependent fallback to the Thin default embedded in the former variable font.
- The daily-benefit hand/coin row and purple group banner artwork use mockup-derived assets.
- Large text uses a `1.13` multiplier over the normal Home text scale. The account card grows from 326 to 342 design pixels in large-text mode so the three action buttons do not overflow.
- Header and bottom navigation remain fixed while Home content scrolls. Header search jumps to the benefits section.
- Amount visibility, NH/other-finance tabs, account-number copy, account details, transfer flow, and data-management screens are wired.
- The Home account logo is a 48×48 blue rounded square. Shared `BankLogo` now places every bank/security mark on an opaque brand-color rounded-square tile throughout account, recipient, picker, and transfer screens; Toss Bank/Securities reuse the transparent Toss mark in white on the common Toss-blue tile.
- The Home `한도해제` action has its own route to `lib/ui/limit_release_screen.dart`; `거래내역` continues to open the existing account-details flow.
- `LimitReleaseScreen` reproduces the supplied top and scrolled reference states as one continuous 588×1280 scrollable page. Its back/title/home/search header remains fixed, while the current primary account (or the reference fallback account) and the Korean guidance copy scroll underneath it.
- The Home `거래내역` action opens `AccountDetailsScreen`, now matching the supplied `거래내역조회` top and scrolled mockups. The page keeps its header and account identity fixed, scrolls away the balance/actions/TLJ banner, pins the one-month filter beneath the account identity, and renders current ledger entries as dated deposit/withdrawal rows with running balances.
- The Home `이체` action opens `TransferRecipientScreen` directly on the account-number/bank entry view. That view reproduces the supplied recipient mockup with back/cancel controls, disabled Next state, four recipient tabs, and the empty recent-transfer state; account numbers use a digits-only system keyboard rather than the former permanently visible custom keypad.
- Manual recipient entry now matches the original selected-bank states: choosing a bank inserts its rounded-square logo and hides the lookup helper, the lower controls compact upward, and `다음` remains gray until a source account, bank, and 6–20 digit destination account are present. Input is capped at 20 digits; the valid state uses the sampled original `#1F9A3F` green with pure-white action copy.
- Recent recipient rows use the catalog bank label/logo, the original lighter subtitle treatment, and a custom five-point favorite mark. The favorite is a gray outline when inactive and the sampled original green fill when active; tapping it persists the recipient favorite state. The original `삭제하기` management link is also present above populated recent rows.
- The bank/security picker is one continuous bottom-sheet route. Its title and close button remain fixed while the segmented control and two-column institution list scroll together. The bank tab follows the supplied row order through `지방세입`; the securities tab follows the supplied 24-entry order.
- Picker logos reuse the sharp 1024×1024 sources already imported from the sibling `app_hq/bank_icons` directory (52 of the current 56 logo assets are byte-identical to those source files). `BankLogo` sizes them through layout constraints instead of an extra transform/raster-cache layer, clips the final tile rather than the transparent/circular source silhouette, and supplies an institution-specific background color so the visible outer shape matches the rounded-square reference treatment.
- Secondary copy on the limit-release, transaction-history, transfer-recipient, and institution-picker screens uses the darker Home muted tone (`#62696B`) with medium/semibold rendering so it remains legible on physical Android devices.
- Transaction-history type labels (`입금`/`출금`) above the right-aligned amounts use semibold text so they remain clear on physical Android displays.
- The three data-management tabs keep their content inside the bottom system safe area, so account/recipient action buttons and the lowest list content stay above Android's three-button or gesture navigation bar.
- Transfer-flow accents use the shared All One green (`#159757`) across recipient entry, review, PIN indicators/keypad, and the failure-popup action. Amount and review bottom actions respect Android's system inset; both amount-keypad digits and the white PIN digits use bold (`w700`). App typography no longer uses `w800`; all former `w800` declarations are normalized to `w700`.

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
- Home header fidelity update on 2026-09-18:
  - The globe, notification bell, and menu/search marks now use `assets/images/ref_header_actions.png`, extracted directly from the supplied original-app screenshot, instead of approximate custom painters.
  - Home uses a fixed 54-design-pixel top inset so devices with a taller iOS safe area do not push the complete header and content lower than the 588×1280 reference canvas.
  - Signed-in names keep the reference trailing `...` with a separately spaced `님`; the fortune label has stronger white copy, the NH selection dot is smaller and raised, and the amount-visibility control uses the original white pill, gray outline, and dark label.
  - `test/goldens/preview_15_home_comparison.png` is the signed-in zero-balance comparison render created specifically for visual review against the supplied original screenshot.
- Typography weight normalization on 2026-09-18:
  - All app `FontWeight.w800` declarations were changed to `w700`; the transfer amount-keypad digits and their variable-font axis now also use 700.
  - Targeted Dart analysis passed for all three changed UI files and `test/widget_test.dart`; the focused transfer-flow widget test passed.
  - Full `flutter analyze` has no errors but reports the existing Flutter 3.47 deprecation info for `ReorderableListView.onReorder` in `data_management_screen.dart`.
- Home typography fidelity pass on 2026-09-19:
  - Removed the unintended 13% scale from normal Home text, retained the 13% boost only for large-text mode, and tuned the shared header, account-card, section, floating-action, and navigation typography against the original-app screenshot.
  - The account balance and visibility pill now share a centered axis; the balance was separately OCR-measured against the original `0원` glyph bounds, widened/raised accordingly, and the pill/action copy was enlarged to the measured reference bounds. The action row is 61 design pixels high with the original bottom spacing, and the account-card shadow is softer.
  - Added the broad, content-bound cyan/green radial glow behind the upper Home content. It scrolls with the source content and replaces the former flat background around the finance tabs and account card.
  - Targeted Dart analysis and the Home text-scale widget test passed. Both Home golden tests passed without updating their baselines after the final render.
  - `/tmp/all_one_home_vs_original_card_fixed.png` is the latest side-by-side review artifact. Remaining whole-screen differences come from intentionally different live banner/promotion content and system status-bar rendering, not from the common Home typography or account-card sizing.
- Transaction-history fidelity pass on 2026-09-19:
  - The top transaction-history screen was measured against the supplied original-app capture on the normalized 588x1280 canvas. Header, account identity, balance, actions, promotion, filter, date range, balance toggle, transaction rows, and dividers were repositioned and retuned to the measured bounds.
  - The back mark, header home/menu marks, NH account tile, account chevron, and 50%-off promotion now use clean crops from the supplied original screenshot so their shapes no longer depend on approximate Material icons or painters.
  - The review fixture now reproduces the original date window, two transaction entries, channel label, amounts, and running balances. `test/goldens/preview_9_transaction_history_top.png` and `preview_10_transaction_history_scrolled.png` are the reviewed clean captures; `/tmp/transaction_details_comparison.png` places the original and current top render side by side at the same scale.
  - Targeted Dart analysis and the focused transaction-history golden test passed after the final visual pass.
- Transaction-history filter fidelity pass on 2026-09-21:
  - Rebuilt the filter bottom sheet from `IMG_1419.MP4`: matching sheet height and section order, four range presets, monthly/range modes, oldest/newest order, deposit/withdrawal/all types, All One green selection states, detail toggle, and fixed confirm action.
  - Rebuilt the nested year/month wheel sheet with a long year history, all 12 months, reference selection styling, and support for choosing a future month so the app can reproduce the source app's validation flow.
  - Future start dates now show the source video's custom Korean warning dialog instead of silently preventing selection or showing inline validation.
  - Added widget coverage for filter structure, range switching, month picker, and future-date validation, plus reviewed golden checkpoints `preview_9a_transaction_history_filter.png` and `preview_9b_transaction_history_month_picker.png`.
- Frequent-recipient tab fidelity pass on 2026-09-21:
  - Rebuilt the `자주` tab in the manual transfer-recipient screen from the supplied original-app capture, including the full-height category selector, name/alias search field, registration link, NH Smart Banking import hint with dismiss action, and original empty-state copy/layout.
  - Retuned the shared manual-entry title, field widths, muted copy, action button, tabs, and top controls against the normalized 588×1280 reference canvas.
  - Added widget assertions for the new controls and dismissible hint plus the reviewed `preview_11a_transfer_recipient_frequent.png` golden checkpoint. `/tmp/transfer_frequent_comparison.png` is the final original-versus-current side-by-side review artifact.
  - The frequent-recipient search field now uses `assets/images/ref_transfer_search.png`, cropped directly from the supplied original-app screenshot, instead of Flutter's approximate Material search glyph. The golden harness explicitly settles the asset before capture; `/tmp/transfer_frequent_search_icon_comparison.png` is the reviewed side-by-side result.
- Selected-bank recipient-entry fidelity pass on 2026-09-21:
  - Reproduced both supplied original-app states: selected NH with a blank account/disabled action, and selected NH with a valid six-digit account/green action. NH and Shinhan shared logo tile colors/scales were sampled and retuned against the originals.
  - Added behavior coverage for the 6–20 digit boundary, white enabled action copy, helper removal, selected bank logo, 20-digit input cap, populated recent-recipient logo, and persistent gray-outline/green-fill favorite states.
  - Added reviewed golden checkpoints `preview_11b_transfer_recipient_selected_bank.png` and `preview_11c_transfer_recipient_valid_account.png`; `/tmp/transfer_selected_bank_comparison.png` and `/tmp/transfer_valid_account_comparison.png` are the original-versus-current side-by-side review artifacts.
  - `flutter test test/widget_test.dart`: 19 passed. `flutter test test/bank_catalog_test.dart`: 3 passed. `flutter test test/preview_golden_test.dart`: 7 passed. `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
- App-wide institution-logo replacement on 2026-09-21:
  - Replaced the former 56 `bank_*`/`security_*` image files with all 48 high-resolution rounded-square PNGs supplied in `assets/logonh`, renamed to semantic `assets/images/logo_*` filenames and mapped through `BankCatalog`.
  - Added complete image mappings for previously simulated securities logos, including Meritz, Bookook, SK, Eugene, LS, iM, Woori Investment, and BNK Securities; shared financial brands reuse one new source image where appropriate.
  - `BankLogo` now renders the complete supplied tile artwork, normalizes the unequal source margins per asset, requests a 256-pixel decoded cache size, and provides code-rendered fallbacks for the post office and four government collection codes that were not included in the supplied folder.
  - Removed all obsolete logo files from the project and regenerated/reviewed the affected Home, recipient, bank-picker, securities-picker, and transaction-history golden baselines.
  - `flutter test test/widget_test.dart test/bank_catalog_test.dart`: 22 passed. `flutter test test/preview_golden_test.dart`: 7 passed in comparison mode. `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
- Recent-recipient institution-line fidelity pass on 2026-09-21:
  - The saved-recipient subtitle now renders the complete Korean institution name (`신한은행`), uses a 20-pixel regular weight, and the lighter `#999999` gray measured from the supplied original-app capture.
  - Increased the selected NH tile from 38 to 46 design pixels and the saved-recipient Shinhan tile from 53 to 62 design pixels to match the visible logo bounds in the normalized original. The selected `NH농협` label now uses `w500` instead of `w700`.
  - Added widget assertions for exact copy, typography, both logo sizes, and the selected-label weight; regenerated the two selected-bank golden checkpoints and reviewed `build/comparisons/recipient_logos_original_vs_updated.png` side by side with the normalized original capture.
  - The focused widget test and golden comparison passed. `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
- Saved-recipient transfer amount/PIN fidelity pass on 2026-09-21:
  - Tapping a saved recipient now opens the amount-entry screen with the recipient name/account centered at the top. The bottom action stays gray at zero and turns All One green only after a positive amount is entered; amount shortcuts and the custom keypad update the same amount state.
  - The enabled amount action now opens the PIN entry directly. PIN entry is a rounded white bottom sheet over a dimmed recipient header, retains the secure randomized four-column keypad, and uses the two faint reference symbols cropped from the supplied original-app screenshot. The bottom-left shuffle action visibly re-randomizes the numeric keys.
  - Added widget coverage for the complete saved-recipient amount/PIN flow and reviewed golden checkpoints `preview_11d_transfer_amount_empty.png`, `preview_11e_transfer_amount_5000.png`, and `preview_11f_transfer_pin.png`.
  - Final original-versus-current review artifacts are `build/comparisons/flow_amount_empty_original_vs_updated.png`, `flow_amount_5000_original_vs_updated.png`, and `flow_pin_original_vs_updated.png`. The widget suite passed; focused golden comparison passed; `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
  - The PIN popup's bottom action row is independent from the four-column number grid: shuffle, delete, and OK are now centered at the three equal horizontal thirds of the full sheet, matching the original screenshot. Widget coverage asserts all three centers and the PIN golden was regenerated and rechecked.
  - The bottom-row shuffle and delete marks now use exact 100×100 crops from the supplied original PIN screenshot (`ref_transfer_pin_rearrange.png` and `ref_transfer_pin_delete.png`) rather than approximate Material icons. The row is raised three design pixels, and its two outer actions are inset while the middle action stays fixed; asserted centers are `(116, 1174)`, `(294, 1174)`, and `(472, 1174)` on the 588×1280 canvas.
  - Wrong transfer PINs now open the reference-style `안내` dialog over a dedicated dimmed recipient/source-account backdrop. The dialog count increases on every failed submission (`1회`, `2회`, …), uses the supplied phone artwork, keeps the five-attempt warning/error code/hotline copy, and returns to PIN entry after confirmation. The reviewed checkpoint is `preview_11g_transfer_pin_failure.png`.
  - PIN rearrangement now shuffles all twelve cells in the upper three rows: ten digits plus both faint reference symbols. The shuffle uses a derangement against the preceding layout so every digit and both symbols visibly move on each rearrange action; widget coverage asserts all twelve positions.
- Per-recipient transfer-warning and confirmation flow on 2026-09-21:
  - Every saved recipient now persists an independent `showTransferWarning` setting. The add/edit-recipient dialog exposes it as `이체 전 추가 확인`; new and legacy recipients default to enabled.
  - After a correct transfer PIN, enabled recipients show the reference `한 번 더 확인해 주세요` warning. Confirming it opens the full `이체확인` page; disabled recipients skip the warning and open that confirmation page immediately.
  - Added persistence/default coverage, data-management toggle coverage, and a widget test covering both enabled and disabled branches. `test/widget_test.dart` passes 20 tests; the focused data/model tests and both new golden comparisons pass.
  - Reviewed checkpoints are `preview_11h_transfer_warning.png` and `preview_11i_transfer_confirmation.png`. `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
  - A follow-up pixel-fidelity pass normalized both supplied originals to the 588×1280 canvas. The warning popup now uses the original 217×69 actions and measured title/body spacing; its dimmed source amount and top cancel use the lighter reference weights. The confirmation page now preserves the full `TRINHTRUNG...` headline, exact `BUIPHUONGT` memo, original row spacing/wraps/underline widths, lower divider, 172×81 and 332×81 bottom actions, and measured value widths. Side-by-side review artifacts are `build/comparisons/transfer_warning_original_vs_updated.png` and `build/comparisons/transfer_confirmation_original_vs_updated.png`.
- Transfer-failure popup fidelity pass on 2026-09-21:
  - Completing the green transfer-confirmation action still returns to Home through the existing `TransferFlowResult.failed` route, but the resulting dialog now reproduces the supplied NH6901 reference: measured 435×429 bounds, matching dim layer, NH wordmark, title/code, reason and contact copy, and 385×57 green confirm action.
  - The header uses `assets/images/ref_transfer_failure_brand.jpg`, cropped from the supplied original-app capture so the yellow/blue NH mark is exact rather than approximated.
  - Added widget coverage for dialog dimensions, copy, brand asset, and dismiss behavior plus the reviewed golden checkpoint `preview_11j_transfer_failure_home.png`. Comparison artifacts are `build/comparisons/transfer_failure_original_vs_updated.png` and `build/comparisons/transfer_failure_popup_detail.png`.
- Four transfer Loading 2 transitions reproduced from `Downloads/1.mp4` on 2026-09-21:
  - All four transitions reuse the exact 20-frame `assets/images/loading_original.png` APNG at the measured 120×120 box `(234, 581)` on the 588×1280 canvas and a `0x7E000000` interaction-blocking scrim.
  - Home → recipient runs for 400 ms: the loader starts over Home without a scrim, then at 233 ms opens the recipient screen and enables the scrim for the remaining segment.
  - Correct PIN → warning runs for 1000 ms over the compact amount/source-account backdrop; its scrim appears after 66 ms. Warning confirmation → `이체확인` runs for 600 ms; its scrim starts at 33 ms, switches from the compact amount state to the original empty confirmation shell at 67 ms, and fills the confirmation data only after loading completes.
  - Final transfer confirmation → result runs for 1400 ms over the populated confirmation page with the scrim active from the first frame. Each playback evicts the APNG image cache so the animation restarts at frame zero.
  - Widget coverage asserts all four phases, timing boundaries, scrim changes, backdrop changes, asset identity, position, and size. Reviewed checkpoints are `preview_11k` through `preview_11n`; the frame-level original/current sheet is `build/comparisons/four_transfer_loadings_video_vs_app.png`.
  - Full `test/widget_test.dart` passed 22 tests. The focused four-loading golden and existing warning/confirmation golden tests pass. The full historical golden file still has only its existing nondeterministic Korean `취소` antialias deltas (0.03–0.04%, 198–294 pixels) when all cases run in one process. `flutter analyze` reports only the pre-existing Flutter 3.47 `ReorderableListView.onReorder` deprecation info in `data_management_screen.dart`.
- Cross-platform typography and layout correction on 2026-09-22:
  - The first correction raised the bundled `NotoSansKR.ttf` variable-font `wght` default from Thin (`100`) to Medium (`500`). A later device-report follow-up replaced that variable asset in the active family with the official static `NotoSansKR-Medium.otf`, eliminating platform-dependent Thin rendering while preserving the existing Bold face.
  - Removed non-uniform paint-only scaling from transaction-history text and replaced it with native font sizes/line heights. Timestamps and left-column values no longer render vertically compressed on iOS, and account identity copy stays inside its fixed header without overflow.
  - The Home balance and visibility pill now form a content-sized row: the pill follows the final balance digit as longer values expand to the right while preserving the mockup's fixed 10-design-pixel gap. The add/edit-recipient dialog is scrollable when the software keyboard reduces the available height, eliminating the reported bottom overflow.
  - Transfer-PIN entry displays one centered green indicator for each entered digit, up to four indicators, matching the original popup while keeping the secure PIN value out of the widget tree and logs.
  - Added the reviewed two-digit checkpoint `preview_11f1_transfer_pin_2_digits.png`; the complete widget/PIN suite passes 31 tests and the regenerated golden suite passes all 11 scenarios independently. `flutter analyze --no-pub` reports only the existing `ReorderableListView.onReorder` deprecation info.
  - Follow-up device screenshots showed that several Home, transaction-history, and transfer styles still explicitly requested `w400`, bypassing the new Medium default. Those overrides now use `w500`; the shared app theme and design canvas also enforce `w500` as the minimum normal-copy weight while preserving `w600`/`w700` emphasis.
  - A complete `lib/` audit removed the final `w400` references, including the bank-picker close icon and the theme fallback. `test/typography_policy_test.dart` now scans production Dart sources and fails if any text or weighted icon requests `100`–`400`, so all screens remain at `w500` or above. The full 65-test suite passes.
  - Transfer failures now propagate through both entry routes. In particular, Home captures the failed result returned through `AccountDetailsScreen`, so `Home → 거래내역 → 이체 → 이체확인` returns Home and opens the NH6901 popup just like the direct Home transfer route. A dedicated widget regression test covers this route.
  - Regenerated all affected golden checkpoints after visual review. `flutter test --concurrency=1` passed all 60 tests, including regression checks for the font registration, Home balance spacing, transaction timestamp proportions, and keyboard-constrained recipient editor. `flutter analyze` reports only the pre-existing `ReorderableListView.onReorder` deprecation info.
  - iOS Simulator and Android debug smoke builds were explicitly stopped at the user's request. Flutter's automatic UIScene migration was fully reverted, Android Gradle configuration remained unchanged, and no platform build process was left running.
- App-wide high-contrast text pass on 2026-09-22:
  - All neutral gray copy now renders as solid black across the shared theme, design canvas, Home, authentication, PIN, limit release, transaction history, recipient entry, amount/PIN transfer, warning/confirmation, and failure popup screens.
  - Semantic colors remain intact: white action copy and green/red/blue status or transaction text were not flattened to black. Gray backgrounds, borders, switches, and icons also remain unchanged.
  - The app theme explicitly sets black `onSurface`, `onSurfaceVariant`, disabled, field label, field hint, and every base text-theme color while retaining the app-wide minimum `w500` rule. Updated golden baselines cover the intentional contrast change.
  - All 54 non-golden tests pass. All 11 golden export scenarios regenerated successfully; the transaction-history golden also passes in focused comparison mode. `flutter analyze --no-pub` still reports only the pre-existing `ReorderableListView.onReorder` deprecation info.
  - A customer TestFlight screenshot still showed the former gray palette after the black-text commit. The screenshot's account identity, filters, dates, and running balances corresponded to colors already removed from current source, confirming it came from an older binary rather than the current widget styles. The project build number was raised from `1` to `2` so the next iOS TestFlight archive and Android package are distinguishable from the stale build. Widget assertions now lock the affected transaction-history title, account identity, filter, balance visibility, empty state, timestamp, recipient, and running-balance text to solid black. Both focused widget checks, the typography policy, and the focused transaction-history golden pass; `flutter analyze --no-pub` continues to report only the pre-existing `ReorderableListView.onReorder` deprecation info.
  - The active `w500` family now uses the official static `assets/fonts/NotoSansKR-Medium.otf` instead of the variable `NotoSansKR.ttf`, whose internal Thin identity could still be selected differently across platform font engines. Explicit `NotoSansKR` family references were migrated to `NotoSansKRMedium`; the old variable file is no longer bundled. The Home clover and grinning-face emoji are painted locally so they remain stable without depending on platform emoji fallback. All intentional font-rendering golden baselines were visually reviewed and regenerated. The full 66-test suite passes; `flutter analyze --no-pub` still reports only the existing `ReorderableListView.onReorder` deprecation info.

## Known limits and next-session checklist

- This workspace may not be a Git worktree. If `git status` returns no repository, do not assume version history is available.
- Release Android currently uses the debug signing configuration. Do not treat the current APK as production-signed.
- Xcode Cloud requires `ios/ci_scripts/ci_post_clone.sh`. A clean checkout does not contain the ignored `ios/Flutter/Generated.xcconfig`; the post-clone script installs pinned Flutter 3.38.10, fetches iOS artifacts and Dart packages, installs CocoaPods when needed, runs `pod install`, and verifies all generated release configuration files before Xcode archives `Runner.xcworkspace`. Keep Flutter at 3.38 or newer because current Firebase plugins use the iOS scene lifecycle API introduced in Flutter 3.38.
- iOS minimum deployment target is 15.0. Build/smoke-test iOS when an iPhone or suitable simulator is available, especially after native launch/status-bar changes.
- At the start of any new task: read `AGENTS.md` and this file, inspect status, locate the exact widget/symbol, preserve unrelated edits, then run the narrowest relevant test before expanding verification.
