# Firebase Integration Write-up

This document summarizes the experience of connecting the Flutter app to Firebase, errors encountered during development, and how those errors were resolved. Replace the image placeholders with screenshots before exporting to PDF.

## Summary

Project: individualproject2

Primary Firebase services used:
- Authentication (Email/password and development anonymous fallback)
- Firestore (document database, composite indexes)
- Storage (image uploads)

During development the app runs on web, mobile and desktop. Web introduced several edge-cases (auth domains, webchannel write errors) that required extra diagnostics and rules fixes.

---

## Steps followed to connect to Firebase

1. Set up a Firebase project in the console and enable Firestore and Authentication.
2. Generated platform configuration using FlutterFire CLI which produced `lib/firebase_options.dart`.
3. Added the generated config and checked `android` and `ios` native config files (`google-services.json`, `GoogleService-Info.plist`) when building mobile.
4. Initialized Firebase early in app startup using `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` with a web fallback in `FirebaseService.initialize()`.
5. Implemented sign-in flows and added a debug anonymous sign-in fallback during development to avoid unauthenticated listen/write errors on web/desktop.

---

## Notable errors & resolutions (include screenshots)

### 1) Firestore rules compile warning: `Invalid function name: where`

- Error: During `firebase deploy` the rules compilation failed with a message indicating `request.query.where` usage was unsupported in the target rules runtime.
- Cause: The rules attempted to inspect the query using `request.query.where(...)`, which is not supported.
- Fix: Replaced the unsupported construct with a development-safe alternative and added a comment to tighten before production.

Screenshot placeholder: `![](assets/screenshots/rules_compile_warning.png)`

---

### 2) Firestore permission-denied when sending messages (web)

- Error: When sending messages from the web client a batched write attempted to update the chat document (`lastMessage`/`lastSentAt`) and the server responded with `permission-denied`. DevTools Network showed a 400 (Bad Request) for the Firestore webchannel POST.
- Cause: The Firestore update rule inspected `request.resource.data.keys()` which contains the entire resulting document, not just written fields, causing the rule to reject updates that only intended to write `lastMessage`/`lastSentAt` when other fields existed in the doc.
- Fix: Updated the rules to use `request.writeFields.hasOnly([...])` and `request.writeFields.hasAny([...])` so the rule checks only the fields being written. Also changed client `getOrCreateDirectChat` to read-first before creating to avoid set() being handled as an update on existing docs.

Screenshot placeholder: `![](assets/screenshots/permission_denied_send_message.png)`

---

### 3) Webchannel 400 (Bad Request) on batched writes

- Error: Firestore webchannel POST returned 400 for some batched writes (observed in DevTools Network), often accompanied by FirebaseException with code `permission-denied`.
- Investigation: Added rich pre-commit logging around batched writes (payload shapes and runtime types) and implemented `_sanitizeForFirestore` to convert unsupported runtime types to Firestore friendly primitives.
- Fix: Sanitized payloads and reduced the write payload to a minimal proven-safe payload when appropriate (for `acceptSwap`). Also improved server rules as above.

Screenshot placeholder: `![](assets/screenshots/webchannel_400.png)`

---

### 4) Duplicate FAB heroTag crash (Flutter)

- Error: Hero animation assertion from duplicate `FloatingActionButton` heroTag.
- Fix: Use unique heroTag per chat: `heroTag: 'send-${widget.chatId}'` in `chat_detail_screen.dart`.

Screenshot placeholder: `![](assets/screenshots/hero_tag_crash.png)`

---

## Dart Analyzer report

I ran `flutter analyze` during development. The analyzer reported multiple issues (deprecations, style warnings). These are non-blocking but should be addressed prior to final delivery.

Current analyzer summary (run at time of this write-up):
- Issues reported: ~176 (mostly info/warnings)

Insert analyzer screenshot: `![](assets/screenshots/dart_analyzer.png)`

How to generate the screenshot yourself:
1. Run in project root:

```powershell
flutter analyze
```

2. Capture the console output or take a screenshot of the terminal.

---

## GitHub repository

Repository name: `individualproject2`
Suggested URL (replace if different): https://github.com/kelvintawe12/individualproject2

Include a screenshot of your GitHub repo page if required: `![](assets/screenshots/github_repo.png)`

---

## How errors were debugged (short notes)

- Added detailed debug logging around Firestore writes (`sendMessage`, `acceptSwap`, `getOrCreateDirectChat`) to print currentUser.uid, original and sanitized payloads, and document snapshots.
- Implemented `_sanitizeForFirestore` to ensure batched writes only contain supported primitives, lists, maps, FieldValue, and Timestamp.
- Deployed rules-only after each rules edit to verify server-side behavior quickly:

```powershell
firebase deploy --only firestore:rules --project <your-project-id>
```

- Used DevTools Network tab to capture failing POST requests (filter `webchannel` or requests to `google.firestore.v1.Firestore/Write`).

---

## Next steps before final PDF

- Replace the image placeholders above with screenshots taken from your local runs.
- Re-run `flutter analyze` and capture the detailed analyzer output for the analyzer screenshot.
- Export this Markdown to PDF (or I can produce a PDF for you once images are in place).

---

If you want, I can help place actual screenshots into `assets/screenshots/` and commit them to the repo; tell me which screenshots you have and I will add them to the repo and update this MD file accordingly.
