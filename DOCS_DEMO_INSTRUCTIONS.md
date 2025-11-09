# Demo & Video Instructions (7-12 mins)

This file lists the actions to show in a short demo video (7–12 minutes). The recording should show both the app and the Firebase Console so viewers can see how actions are reflected in the backend.

Suggested flow to record:

1. Intro (15–30s)
   - Short title slide: app name and what the demo covers.
   - Show the Firebase Console project dashboard and Firestore rules/indexes panels briefly.

2. User authentication flow (1–2 min)
   - Show signing up with email/password (or sign in) and verify `users/{uid}` doc appears in Firestore.
   - Demonstrate the anonymous debug sign-in (if used) and explain why it's used for development.

3. Posting/editing/deleting a book (2–3 min)
   - Create a new listing (fill title, description, upload image).
   - Show the listing doc in Firestore (collection `listings`) and the uploaded image in Storage.
   - Edit the listing metadata and show the Firestore update.
   - Delete the listing and show the doc removed from the console.

4. Viewing listings and making a swap offer (1–2 min)
   - Browse listings in the UI and create a swap request for a listing.
   - Show the `swaps/{swapId}` doc being created and the `notifications/{notifId}` doc for the owner.

5. Swap state updates (Pending → Accepted / Rejected) (1–2 min)
   - As the owner, accept a swap and show `swaps/{swapId}` status change to `accepted` and `acceptedAt` timestamp.
   - Show the notification to the requester.
   - Repeat with rejection if time permits.

6. Chat (optional) (1–2 min)
   - Start a direct chat between two signed-in users.
   - Show messages appearing in `chats/{chatId}/messages` and the parent chat doc `lastMessage`/`lastSentAt` updating.
   - If permission-denied previously occurred, show that it now succeeds and explain the rules fix.

7. Wrap-up (15–30s)
   - Summarize design decisions, show final GitHub repo link, and point to the design summary PDF / docs.

Recording tips
- Use a single-screen split (app left, Firebase Console right) or record the app, then quickly switch to the Firebase Console to show the backend reflection of the actions.
- Use high-contrast highlights or slow mouse movements when demonstrating changes in Firestore.
- Narrate key actions briefly and call out the collections and fields being updated.

Commands to run locally (to reproduce during recording):

```powershell
# Run analyzer to show the report
flutter analyze

# Run the app in Chrome
flutter run -d chrome
```

Files to include with submission
- `DOCS_FIREBASE_WRITEUP.md` (this file)
- `DOCS_DESIGN_SUMMARY.md` (design summary)
- `DOCS_DEMO_INSTRUCTIONS.md` (this file)
- A link to the GitHub repo (or include a fork/branch if asked)
- (Optional) example screenshots in `assets/screenshots/` and a short demo video file


---

When you're ready, I can:
- Add placeholder screenshots to `assets/screenshots/` and commit them.
- Export these `.md` files to a single PDF.
- Create a small script that automates taking the analyzer output and saving it to `assets/screenshots/dart_analyzer.txt` for inclusion.
