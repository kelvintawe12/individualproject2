# Design Summary

This document summarizes the database model, swap state modeling, state management approach, and design trade-offs for the `individualproject2` app.

## Database model (Firestore)

Collections and key fields used in the detailed app:

- users/{uid}
  - displayName: string
  - avatarUrl: string
  - createdAt: timestamp

- listings/{listingId}
  - ownerId: string
  - title, description, ... (metadata)
  - createdAt: timestamp

- swaps/{swapId}
  - listingId: string
  - requesterId: string
  - ownerId: string
  - status: string (`pending` | `accepted` | `rejected`)
  - createdAt, acceptedAt, rejectedAt: timestamps

- chats/{chatId}
  - participants: array of userIds
  - createdBy: userId
  - name, avatarUrl (for groups)
  - lastMessage: string
  - lastSentAt: timestamp
  - messages/ (subcollection)

- chats/{chatId}/messages/{messageId}
  - senderId: string
  - text: string
  - imageUrl: string
  - createdAt: timestamp

- notifications/{notifId}
  - recipientId: string
  - type: string
  - payload: map
  - read: bool
  - createdAt: timestamp

- libraries/{userId_listingId}
  - userId: string
  - listingId: string
  - createdAt: timestamp

### ERD notes

The app uses a normalized-ish approach where entities are stored in top-level collections with references by id. Chats have a messages subcollection to keep message history sharded under the chat document.

## How swap states are modeled

- Each `swap` document has a `status` field with possible values:
  - `pending` — a swap request has been sent and awaits owner action.
  - `accepted` — owner accepted the swap; `acceptedAt` set to server timestamp.
  - `rejected` — owner rejected the swap; `rejectedAt` set to server timestamp.

- Transitions are performed using Firestore writes/updates (single-document updates). Important notifications are created when status changes (e.g., `swap_accepted`, `swap_rejected`).

- The minimal payload update approach is used for web (e.g., only updating `status` and timestamp) to avoid webchannel 400 issues caused by unexpected value types.

## State management

- The app uses Firestore `snapshots()` streams in combination with Flutter `StreamBuilder` widgets to drive real-time UI updates (for listings, chats, messages, notifications).
- App-level UI state (shell-level concerns such as which bottom navigation tab is active) is handled with a lightweight Cubit (from `flutter_bloc`). This provides a single, testable source of truth for navigation state and avoids scattering `setState` calls across the shell.
- Local ephemeral UI state that is tightly scoped to a single widget (for example transient animation controllers, obscure text toggles inside a single input, or tiny UI-only toggles) may still use `StatefulWidget` + `setState()` when appropriate. The goal is to avoid global or shared state via `setState`.
- `FirebaseService` remains the centralized helper for Firestore operations and acts as the data layer between UI and Firestore.

Why this change?
- Streams map naturally to Firestore's real-time model for data. For shared UI concerns that must be read/modified from multiple widgets (navigation, global drawers, or other shell-level flags), using a Cubit provides clearer ownership, easier testing, and prevents accidental rebuilds of unrelated widgets.

Quick migration example (what I changed):

- I added a small `AppCubit` (located at `lib/presentation/bloc/app_cubit.dart`) which holds the selected bottom navigation index as an `int` state. The app shell (`lib/app.dart`) now provides the cubit at the top-level using `BlocProvider` and reads it via `BlocBuilder`. Routes that previously used a `setState` callback to switch tabs now call `context.read<AppCubit>().goToX()` inside a post-frame callback.

How to read & update App state (example snippets):

1) Provide the cubit above `MaterialApp` (done in `lib/app.dart`):

```dart
return BlocProvider(create: (_) => AppCubit(), child: MaterialApp(...));
```

2) Read current tab and render the correct child:

```dart
BlocBuilder<AppCubit, int>(builder: (context, selectedIndex) {
  return IndexedStack(index: selectedIndex, children: _screens);
});
```

3) Update the selected tab from anywhere with a BuildContext that has access to the provider:

```dart
context.read<AppCubit>().setIndex(1); // switch to index 1
// or use the provided helpers
context.read<AppCubit>().goToLibrary();
```

This pattern keeps the small in-widget ephemeral state local, while shared/shell state is explicit and testable via Cubit.

## Design trade-offs & challenges

1. Security rules vs. client convenience
   - Tight rules are necessary, but rules that inspect the entire resulting document (`request.resource.data`) can inadvertently reject valid partial updates. We used `request.writeFields` in chat update rules to allow minimal updates and avoid false negatives.

2. Web-specific write-channel problems
   - The Firestore web transport (webchannel) can surface 400 errors when unsupported runtime values are included in batched writes. Fixes included sanitizing payloads and simplifying update payloads (minimal updates) for web.

3. Indexes and query planning
   - Composite indexes are required for compound queries (for example: order notifications by createdAt while filtering by recipientId). We added `firestore.indexes.json` entries and deployed them; server-side index build is asynchronous and must be monitored in the Firebase Console.

4. Offline & eventual consistency
   - Using server timestamps and separate writes for notifications and swaps keeps the model simple. For critical multi-step flows consider using transactions or Cloud Functions to enforce stronger consistency.

5. UX considerations
   - The app prioritizes immediate feedback and uses optimistic UIs where appropriate. For example, messages use a batched write to update both the message (subcollection) and chat document atomically. When batched writes fail, the client surfaces a helpful diagnostic message and captures pre-commit payloads for debugging.

## Minor implementation notes

- Chat document id for direct 1:1 chats is deterministic: `userA_userB` (sorted). This avoids duplicate direct-chat docs and makes lookups simple.
- `getOrCreateDirectChat` now performs a read-first creation to avoid permission issues when `set()` would be treated as an update.
- A `_sanitizeForFirestore` helper ensures payloads only contain supported types (strings, numbers, booleans, FieldValue, Timestamp, lists and maps).


---

If you'd like, I can also produce a simplified ERD diagram (PNG or SVG) and add it to the repo under `assets/docs/`.