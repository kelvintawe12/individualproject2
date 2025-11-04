# BookSwap — Flutter Demo (scaffold)

This repository contains a design spec and a minimal Flutter demo scaffold for BookSwap — a student textbook swapping app. The scaffold is a mock-data demo so you can preview the UI and navigation locally. Full Firebase integration (Auth, Firestore, Storage) is provided as a next step and requires adding your Firebase project configuration files (`google-services.json` / `GoogleService-Info.plist`).

What I added in this commit
- `PROJECT_DESCRIPTION.md` — premium project description & design spec.
- A small Flutter app scaffold (in `lib/`) with mock data and screens: Browse, Post, My Listings, Chats, Settings.

How to run the demo locally
1. Install Flutter on your machine (https://flutter.dev/docs/get-started/install).
2. From the repo root run:

```powershell
# fetch dart dependencies
flutter pub get

# run on connected device or emulator
flutter run
```

Notes about Firebase
- This scaffold currently uses mock data and stubbed service classes so you can run a UI demo without Firebase.
- To enable full functionality (Auth, Realtime listings, image upload, chat), create a Firebase project, enable Authentication (email/password), Firestore, and Storage, then add the platform config files and follow the integration TODOs in `lib/services/firebase_service.dart`.

Firebase preparation steps (what to do next)

1. Create a Firebase project at https://console.firebase.google.com/. Add Android and/or iOS apps to the project.
2. For Android: download `google-services.json` and place it under `android/app/`.
	For iOS: download `GoogleService-Info.plist` and add it to the Xcode project (`Runner` target).
3. Add the Firebase SDK to the app by following the FlutterFire guide: https://firebase.flutter.dev/docs/overview
	- Optionally run `flutterfire configure` from the project root to generate configuration.
4. Implement the TODOs in `lib/services/firebase_service.dart`:
	- Call `Firebase.initializeApp()` in `main.dart` before `runApp()`.
	- Use `firebase_auth` for sign up/sign in, `cloud_firestore` for listings and swaps, and `firebase_storage` for image uploads.
5. Update AndroidManifest/Info.plist with the required permissions (photo access, internet).

If you want, I can implement steps 3–4 for you (wire the app to Firebase, implement auth/listings/upload flows and replace the stubbed `ImageService` with real storage uploads). Provide the Firebase config files or allow me to scaffold the integration with placeholders and instructions to finish locally.

Next steps I can do for you (pick one or more)
- Integrate Firebase services and implement Auth + Firestore flows (requires your Firebase project files).
- Implement Chat and Swap transactions with real Firestore listeners and security rules.
- Add unit/widget tests and CI config.

If you want me to implement full Firebase integration, share the Firebase project details (or allow me to scaffold with placeholder instructions) and I'll continue.
