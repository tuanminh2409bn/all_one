# NH올원뱅크

Flutter recreation of NH All One. Home follows mockups `1`–`5` on a 588×1280 design canvas; entry and loading follow mockups `6`–`9`.

Read [`PROJECT_HANDOFF.md`](PROJECT_HANDOFF.md) before continuing development.

## Flow

- Native launch → campaign splash (6) → certificate login (7) → six-digit PIN (8) → original loading animation (9) → Home.
- On Android 12+, the required Android system splash appears before screen 6. iOS uses screen 6 artwork as its native launch screen.
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

## Verify

```sh
flutter analyze
flutter test test/widget_test.dart
flutter test test/preview_golden_test.dart
```
