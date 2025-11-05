Firebase setup checklist for this project

This file explains the minimum steps to configure Firebase for the BookSwap demo app (web + mobile). Use the included helper script or the FlutterFire CLI to generate `lib/firebase_options.dart` and add platform config files.

1) Prerequisites
- Install Flutter and set up Flutter dev environment.
- Install Dart pub global tools (for FlutterFire CLI):
  - `dart pub global activate flutterfire_cli`
- (Optional) Install Firebase CLI for other tasks: `npm i -g firebase-tools`

2) Recommended quick setup (Windows PowerShell)
- From project root run the bundled script which attempts to run `flutterfire configure`:

  Open PowerShell and run:

  .\scripts\firebase_configure.ps1

  The script defaults to projectId `bookswapp-3c1af` and will write `lib/firebase_options.dart`.

3) Manual FlutterFire configure
- If you prefer the interactive flow:

  dart pub global activate flutterfire_cli
  flutterfire configure

  Follow the prompts, select your Firebase project and the platforms (android, ios, web). This will update `lib/firebase_options.dart` and guide platform-specific steps.

4) Platform-specific files
- Android: put `google-services.json` into `android/app/` (download from Firebase Console after adding Android app).
- iOS: put `GoogleService-Info.plist` into `ios/Runner/`.
- Web: ensure the `web` block in `lib/firebase_options.dart` matches the values shown in the Firebase Console for your web app.

5) Authentication
- Console → Authentication → Sign-in method: enable the providers you need (Email/Password, Google, etc.).
- Console → Authentication → Settings: add `localhost` to Authorized domains for local web testing.

6) reCAPTCHA & Phone Auth
- If using phone auth or reCAPTCHA Enterprise, configure the required reCAPTCHA Enterprise API and site keys in Google Cloud and Firebase Console.

7) Verify & run
- After configuration run:

  flutter clean
  flutter pub get
  flutter run -d chrome

- Look at the console logs printed by `lib/services/firebase_service.dart` — it prints helpful diagnostics.

8) Troubleshooting
- If you see `configuration-not-found` in the app dialog or console, verify the `apiKey`, `projectId`, and `appId` in `lib/firebase_options.dart` match the web app in Firebase Console.
- If sign-up returns `OPERATION_NOT_ALLOWED`, enable Email/Password in the Console.
- If problems persist, paste the Network POST response body from the failing identitytoolkit request (Chrome DevTools → Network → select request → Response).

If you'd like, I can (in this repo):
- Force web options temporarily for quick debugging,
- Add more mapping from Firebase error codes to helpful UI actions,
- Or walk you through a live `flutterfire configure` run.

