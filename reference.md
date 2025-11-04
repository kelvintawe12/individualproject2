Application state is handled exclusively by either BLoC/Cubit, Provider, Riverpod, GetX, or an equivalent library. The state management technique used is explained in detail such that the audience can know how to implement it if they have never used it before. No global setState calls appear outside trivial widget rebuilds. The folder hierarchy separates presentation, domain, and data.



Fully working signup, login, and logout with Firebase Auth. Email verification enforced (user cannot log in until verified). User profile data created and displayed. Demo shows corresponding Firebase console user entries, including email verification status.


All CRUD ops implemented and demonstrated with Firebase console evidence: (a) Create: new book saved with cover image, (b) Read: feed shows all listings, (c) Update: edits reflected in Firestore, (d) Delete: record removed. Explanation clear for each operation.


Swap offers work end-to-end. Tap “Swap” → listing moves to “My Offers,” state updates to Pending, and both sender & recipient see changes instantly. State mgmt (Provider/Riverpod/Bloc) keeps UI reactive. Demo shows Firestore doc changes in real-time.


BottomNavigationBar implemented with Browse, My Listings, Chats, Settings. Navigation between screens smooth. Settings includes toggle switches and profile info. Demo shows all screens working.


Two-user chat works after swap initiation. Messages stored in Firestore, update in real time. Video shows chat messages and corresponding Firestore updates. Explanation covers how chat collections are structured and synced.

