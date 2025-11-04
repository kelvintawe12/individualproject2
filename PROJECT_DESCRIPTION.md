# BookSwap — Project Description & Premium UI/Design Spec

This document describes the BookSwap app (student textbook swapping marketplace) and provides a premium UI/UX design spec, data model, components, and implementation checklist that maps directly to the assignment requirements in `TODO.md`.

## Elevator pitch

BookSwap is a polished mobile app for students to list textbooks they want to swap, discover listings in a beautiful feed, and initiate swap offers. It combines Firebase-backed real-time sync with a modern, tactile UI built with Flutter. The design focuses on clarity, speed, and trust: clean listing cards, clear states (Available, Pending, Exchanged), lightweight micro-interactions, and accessible layouts.

## Key product goals

- Enable secure user authentication and profile management (email/password + verification).
- Let users create, read, update, and delete book listings with cover images and conditions.
- Support swap offers and real-time state syncing between sender and recipient.
- Provide a familiar bottom navigation with Browse, My Listings, Chats, and Settings.
- Offer a premium, mobile-first UI with responsive, accessible components.

## Platform & tech choices (recommended)

- Frontend: Flutter (Android & iOS). Use Riverpod for state management (or Provider/Bloc if preferred).
- Backend: Firebase — Authentication, Firestore (real-time), Cloud Storage (images), optional Cloud Functions for notifications and transactional swap logic.
- Local storage/cache: Hive or shared_preferences for small caches and offline-friendly reads.

## Data model (Firestore collections)

- users (docId = uid)
  - email, displayName, photoUrl, emailVerified, notificationPrefs

- listings (docId)
  - ownerId (ref to users)
  - title
  - author
  - condition (New | Like New | Good | Used)
  - coverUrl (Cloud Storage URL)
  - description (optional)
  - price (optional, if marketplace later)
  - status (Available | Pending | Exchanged | Removed)
  - createdAt, updatedAt

- swaps (docId)
  - listingId
  - senderId
  - recipientId (owner of listing)
  - status (Pending | Accepted | Declined | Completed | Cancelled)
  - createdAt, updatedAt

- chats (docId)
  - participants [uid, uid]
  - messages (subcollection) or messages as separate collection

Security note: Use Firestore security rules to ensure only owners can update/delete their listings and only participants can read/append chat messages.

## Wireframes & Screen list

1. Onboarding / Auth
   - Sign up, Login, Password reset, Email verification screen.

2. Home / Browse Listings (Feed)
   - Top app bar with app name + search field.
   - Filter chips (All | New | Like New | Good | Used) and a sort menu (Newest, Closest, Condition).
   - Listing cards grid/list (album-style): cover image, title, author, condition chip, owner name, `Swap` button.
   - Skeleton loaders while fetching.

3. Listing Details
   - Large cover image, meta (title, author, condition, owner), description, action buttons (Swap, Message owner if allowed, Edit/Delete if yours).

4. My Listings
   - Segmented control for Active / Pending / Exchanged.
   - Each item shows status badge and quick edit/delete.

5. My Offers
   - Page showing swaps you initiated and swaps received; each shows live status and actions (Cancel, Accept, Decline).

6. Chats
   - List of conversations with last message preview and unread counts.
   - Chat screen with message bubbles, image attachments, and simple read receipts.

7. Settings
   - Profile info, notification toggles, sign out.

## Premium UI Design System

Visual language: clean, modern, soft shadows, rounded corners, bright accent color, generous white space.

Color palette
- Primary Accent: #0D6EFD (Vivid Blue) — buttons, active icons
- Secondary Accent: #6F42C1 (Purple) — badges, highlights
- Background: #F7F9FC (light) and surfaces #FFFFFF
- Text primary: #0F1724 (dark slate)
- Muted text: #667085
- Error: #EF4444 (for validation errors)

Typography
- Headings: Inter (600) — sizes: H1 28sp, H2 22sp, H3 18sp
- Body: Inter (400) — 14–16sp
- Buttons: Inter (600) 14sp, uppercase for primary CTAs

Spacing & layout
- Base spacing unit: 8dp. Use multiples (8/16/24/32).
- Card radius: 12dp; Button radius: 10dp; App bar radius: 0.

Components
- Listing Card
  - Cover (left) 80×120, or full-bleed square in grid view.
  - Title (bold), author (muted), condition chip (color-coded), `Swap` CTA.
  - Shadow: subtle (elevation 2), hover/press: scale 0.98 + elevation 6.

- Condition Chip
  - New: green (#10B981), Like New: teal, Good: amber, Used: gray

- Bottom Navigation
  - 4 items: Browse (home), My Listings, Chats, Settings.
  - Active icon tinted Primary Accent with small indicator bar.

- Swap Button / State
  - Primary CTA when listing available. On tap, show confirmation sheet/modal with microcopy explaining the swap action.
  - On pending: disable primary CTA and replace with `Pending` pill + `Cancel offer` secondary action.

- Modals & Sheets
  - Use rounded-top modal sheets for actions (create listing, confirm swap).

Motion & micro-interactions
- Subtle transitions for navigation and card taps (200ms ease-out).
- Use Lottie or micro-animations for success states (e.g., swap accepted).

Accessibility
- Ensure 4.5:1 contrast for primary text and buttons where possible.
- Provide semantic labels for images and interactive elements.
- Support dynamic type / font scaling.

## Interaction details and edge cases

- Email verification: Prevent core actions (posting) until verification completed. Show in-app banner prompting verification with a resend button.
- Image uploads: Compress images client-side, upload to Firebase Storage, show upload progress.
- Race conditions for swaps: Use Firestore transactions or Cloud Functions to atomically change listing status and create swap doc.
- Offline: allow read-only cached listings and queue actions for retry.

## Mapping to assignment requirements

- Authentication: Sign up/login/logout, email verification, profile — covered in Auth screens above.
- Book Listings CRUD: Create listing flow with camera/gallery, edit/delete UI in My Listings, browse feed.
- Swap functionality: Swap button, swaps collection, Pending state, real-time updates via Firestore listeners.
- State management: Use Riverpod or Bloc; normalize state for listings/swaps for instant UI updates.
- Navigation: BottomNavigationBar with four screens described above.
- Settings: Notification toggles (local simulation) and profile display.
- Chats (bonus): Chat list and message screen scaffolded; messages stored under chats/messages or as separate collection.

## File & folder suggestions (Flutter)

- lib/
  - main.dart
  - app.dart (router + providers)
  - screens/
  - widgets/
  - models/ (Listing, Swap, User, Message)
  - services/ (auth_service.dart, firestore_service.dart, storage_service.dart)
  - state/ (riverpod providers or blocs)

## Required assets & mockups

- App icon (1024×1024)
- Listing placeholder cover image (600×800)
- Condition icons (small SVGs for New/LikeNew/Good/Used)
- Lottie success animation (optional)

## Implementation checklist (quick)

1. Project scaffold (Flutter) + Firebase setup — include `google-services.json` / `GoogleService-Info.plist`.
2. Authentication (email/password) + email verification UI and logic.
3. Firestore schema + security rules for listings/swaps/chats.
4. Listing CRUD UI + image upload to Cloud Storage.
5. Swap creation flow + transactional state updates.
6. Real-time listeners for listings and swaps.
7. Bottom navigation + screens.
8. Settings + local notification simulation.
9. Chat integration (bonus).

## Next steps & optional premium enhancements

- Add geolocation and distance-based sorting.
- Implement push notifications using Firebase Cloud Messaging.
- Add rating/trust system for users.
- Polish animations, add onboarding tour, and prepare Play/App store assets.

---

If you'd like, I can now:
- Generate a polished `README.md` using this content.
- Scaffold the Flutter project files (main.dart, sample screens, and providers) that implement the design system.
- Create UI mockups (Figma-compatible JSON or simple PNG wireframes).

Tell me which next step you'd prefer and I will act on it.
