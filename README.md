# NH올원뱅크

Flutter recreation of NH All One. Home follows mockups `1`–`5` on a 588×1280 design canvas; entry and loading use mockups `7`–`10`.

Read [`PROJECT_HANDOFF.md`](PROJECT_HANDOFF.md) before continuing development.
The Vietnamese work summary is in [`TONG_KET_CONG_VIEC.md`](TONG_KET_CONG_VIEC.md).

## Flow

- Native app-logo launch → anniversary campaign splash (10) → certificate login (7) → six-digit PIN (8) → original loading animation (9) → Home.
- Android 12+ and iOS show the app logo on their native launch screen before Flutter campaign screen 10.
- Guest and Firebase Email/Password login/register flows are available. Signed-in accounts use an account-scoped secure PIN.
- Home is one long native Flutter page matching mockups `1`–`5`, with account/data management and transfer flows.

## Firebase

- Project: `all-one-fa936`
- Android: `com.nhallone.all_one`
- iOS: `com.nhallone.allOne`

Enable **Email/Password** in Authentication if it is not already on:

https://console.firebase.google.com/project/all-one-fa936/authentication/providers

Deploy Firestore rules:

```sh
firebase deploy --only firestore:rules --project all-one-fa936
```

## Run

```sh
flutter pub get
flutter run
```

Android builds use the local Flutter SDK and Android Studio's bundled JDK; no JDK 21 override is needed. The Android toolchain is aligned with Flutter 3.47.5: Gradle 9.3.1, Android Gradle Plugin 9.1.0, Kotlin 2.4.0, and `flutter.ndkVersion` (28.2.13676358 in this SDK). Use Flutter 3.44 or newer for AGP 9 compatibility; the current Mac mini environment uses Flutter 3.47.5 and Java 25.0.3. Keep the existing `android.builtInKotlin=false` and `android.newDsl=false` compatibility flags until the Firebase and preferences plugins support the migration. In Android Studio, open the project root, select `lib/main.dart` and the Android device, then Run; sync Gradle if prompted.

## Verify

Xcode Cloud uses Flutter 3.47.5, matching the current local SDK and lockfile. Its post-clone script prepares the release configuration and generated Swift plugin package before Xcode archives `ios/Runner.xcworkspace`. Build `1.0.0+4` includes the screen-10 launch flow, reference-matched Home effects, and lighter gray transaction-history metadata.

For a customer-installable Android APK, run `flutter build apk --release`. The existing release configuration uses the local debug signing key; this is suitable for direct testing, not a production Play Store release. Keep that key consistent when installing updates over an existing customer build.

```sh
flutter analyze
flutter test test/widget_test.dart
flutter test test/preview_golden_test.dart
```
