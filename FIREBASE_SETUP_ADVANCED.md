Advanced Firebase setup & rules (detailed)

This file supplements the repo's basic `FIREBASE_SETUP.md` with exact rules and practical steps for deploying, testing, and seeding Firestore/Storage for the BookSwap demo.

What's included in this repo now:
- `firestore.rules` — secure Firestore rules (owner-only writes, participant-only chat access).
- `storage.rules` — Storage rules to allow authenticated image uploads under `images/` paths.

Quick checklist to get the app working end-to-end (web & mobile)
1) Enable Email/Password provider and authorized domains
  - Console → Build → Authentication → Sign-in method → enable Email/Password
  - Console → Build → Authentication → Settings → add `localhost` to Authorized domains for web testing

2) Apply Firestore rules
  - Option A (Console): Firebase Console → Build → Firestore Database → Rules → paste `firestore.rules` content → Publish
  - Option B (CLI): Install firebase-tools, login, and run: `firebase deploy --only firestore:rules`

3) Apply Storage rules
  - Console → Build → Storage → Rules → paste `storage.rules` content → Publish
  - Or: `firebase deploy --only storage:rules`

4) Test rules in simulator
  - Use the Rules Simulator in Firestore Console and run these simulations:
    * Read listings with request.auth.uid = <your uid> → should succeed
    * Create listing with request.auth.uid = <your uid> and request.resource.data.ownerId = same uid → should succeed
    * Create listing with ownerId != request.auth.uid → should be denied
    * Create chat with participants array containing request.auth.uid → should succeed
    * Create message as senderId == request.auth.uid in chats/{chatId}/messages → should succeed

5) Optional: Deploy rules from repo
  - From repo root (where firebase.json sits):

```powershell
# install if needed
npm install -g firebase-tools
firebase login
# deploy both rules files
firebase deploy --only firestore:rules,storage:rules
```

6) Seeding sample documents (manual)
  - You can manually add a `users` document (doc id = your uid) and a `listings` document in the Console. Ensure `ownerId` matches the uid used for testing.

Example `listings` document to paste into the Console:
```
{
  "title": "Example Book",
  "description": "Demo listing",
  "ownerId": "efqsbx0UPxVvX2EJnyY6UuqwwOg1",
  "imageUrls": [],
  "createdAt": {"_seconds": 1630000000, "_nanoseconds": 0}
}
```

7) If you still get permission-denied after applying rules
  - Confirm the app is signed in (the in-app developer info shows current user uid)
  - Confirm `request.auth.uid` in the Rules simulator equals the uid shown in the app
  - Copy the failing Network request response body (DevTools → Network → failing request → Response) and share it — it contains the server-side reason

8) Security & cleanup
  - If you temporarily used permissive rules for debugging, make sure to revert to the secure `firestore.rules` provided here.
  - Consider adding file size limits and content-type checks for uploaded images.

Need help with any of these steps?
- I can produce a short seeder script (Node or Dart) to create test `users`/`listings`/`chats` entries.
- I can also prepare `firebase.json` snippets or CI steps to deploy rules automatically.

Tell me which you'd like next: seed script, run-through of enabling auth in Console, or CLI deploy help.