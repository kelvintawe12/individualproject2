import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';

// NOTE: This Firebase service file contains a small initialize implementation
// so the app will initialize Firebase using native platform config files
// (google-services.json / GoogleService-Info.plist). Further methods remain
// stubbed and should be implemented once Firestore/Auth/Storage are wired.

class FirebaseService {
  /// Initialize Firebase. Call this early in app startup (main).
  static Future<void> initialize() async {
    // When platform config files are present (android/google-services.json
    // and ios/GoogleService-Info.plist), calling Firebase.initializeApp()
    // without options lets the native SDK read them automatically.
    // We attempt to initialize using the generated DefaultFirebaseOptions.
    // On desktop platforms where DefaultFirebaseOptions are not configured
    // the getter throws UnsupportedError; catch that and fall back to
    // web options so development on Windows/mac/linux works.
    try {
      // Use generated Firebase options when available so web and all
      // platforms initialize correctly. For mobile, this will also read
      // native config files if present.
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (kDebugMode) debugPrint('Firebase initialized (with DefaultFirebaseOptions).');
    } on UnsupportedError catch (e) {
      // Desktop platforms may not have been configured by FlutterFire CLI.
      if (kDebugMode) debugPrint('DefaultFirebaseOptions not configured for this platform: $e');
      if (kDebugMode) debugPrint('Falling back to DefaultFirebaseOptions.web for initialization.');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      if (kDebugMode) debugPrint('Firebase initialized (fallback to web options).');
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase initialization failed: $e');
      // Provide a helpful hint for common configuration issues (web/native config mismatch)
      if (e.toString().contains('configuration-not-found') || e.toString().contains('DefaultFirebaseOptions')) {
        debugPrint('Hint: configuration-not-found usually means your Firebase client config does not match a registered Firebase app.');
        debugPrint(' - Verify lib/firebase_options.dart matches the Web app (apiKey, appId, projectId) in Firebase Console.');
        debugPrint(' - Ensure Email/Password sign-in is enabled (Console → Authentication → Sign-in method).');
        debugPrint(' - For web: ensure localhost is added to Authorized domains (Console → Authentication → Settings).');
        debugPrint(' - You can (re)generate configuration using the FlutterFire CLI or the included script: scripts\\firebase_configure.ps1');
      }
      rethrow;
    }
    // Post-initialization diagnostics helpful for debugging web/desktop issues.
    try {
      if (kDebugMode) {
        debugPrint('kIsWeb = $kIsWeb');
        debugPrint('Default target platform = $defaultTargetPlatform');
        // List configured Firebase apps
        final apps = Firebase.apps.map((a) => a.name).toList();
        debugPrint('Configured Firebase apps: $apps');
        // Print the active app options (safely)
        final active = Firebase.app();
        debugPrint('Active Firebase app name: ${active.name}');
        debugPrint('Active Firebase options: apiKey=${active.options.apiKey}, projectId=${active.options.projectId}, appId=${active.options.appId}, authDomain=${active.options.authDomain}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase post-init diagnostic failed: $e');
    }

    // DEBUG helper: if running locally in debug and there's no signed-in user,
    // attempt an anonymous sign-in so Firestore listen/write streams don't fail
    // due to unauthenticated requests while developing on web/desktop.
    // This is safe for local development only and will be skipped in release.
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (kDebugMode && currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
          if (kDebugMode) debugPrint('FirebaseService: signed in anonymously for debug/dev.');
        } catch (e) {
          if (kDebugMode) debugPrint('FirebaseService: anonymous sign-in failed (may be disabled in Console): $e');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseService: debug anonymous sign-in check failed: $e');
    }
  }

  /// Sign up with email/password. Return user id or throw.
  static Future<String> signUp(String email, String password) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    return cred.user!.uid;
  }

  /// Sign in with email/password.
  static Future<String> signIn(String email, String password) async {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    return cred.user!.uid;
  }

  /// Send a password reset email.
  static Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Send email verification to the currently signed-in user.
  static Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Upload image to Firebase Storage and return download URL.
  static Future<String> uploadImage(File localFile, Function(double)? onProgress) async {
    final storage = FirebaseStorage.instance;
    final id = const Uuid().v4();
    final ref = storage.ref().child('listings').child('$id.jpg');
    final uploadTask = ref.putFile(localFile);

    uploadTask.snapshotEvents.listen((event) {
      final bytesTransferred = event.bytesTransferred.toDouble();
      final totalBytes = event.totalBytes.toDouble();
      final progress = (totalBytes > 0) ? (bytesTransferred / totalBytes) : 0.0;
      if (onProgress != null) onProgress(progress.clamp(0.0, 1.0));
    });

    final snap = await uploadTask;
    final url = await snap.ref.getDownloadURL();
    return url;
  }

  /// Upload raw image bytes (useful for web where File is not available).
  static Future<String> uploadImageBytes(Uint8List bytes, Function(double)? onProgress) async {
    final storage = FirebaseStorage.instance;
    final id = const Uuid().v4();
    final ref = storage.ref().child('listings').child('$id.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final uploadTask = ref.putData(bytes, metadata);

    uploadTask.snapshotEvents.listen((event) {
      final bytesTransferred = event.bytesTransferred.toDouble();
      final totalBytes = event.totalBytes.toDouble();
      final progress = (totalBytes > 0) ? (bytesTransferred / totalBytes) : 0.0;
      if (onProgress != null) onProgress(progress.clamp(0.0, 1.0));
    });

    final snap = await uploadTask;
    final url = await snap.ref.getDownloadURL();
    return url;
  }

  /// Create a listing document in Firestore.
  static Future<void> createListing(Map<String, dynamic> data) async {
    final col = FirebaseFirestore.instance.collection('listings');
    final payload = Map<String, dynamic>.from(data);
    payload['createdAt'] = FieldValue.serverTimestamp();
    await col.add(payload);
  }

  /// Example: listen to listings collection and call onData with documents.
  static Stream<List<Map<String, dynamic>>> listenListings() {
    final col = FirebaseFirestore.instance.collection('listings').orderBy('createdAt', descending: true);
    return _queryToListStream(col);
  }

  /// Create a swap offer document.
  /// Returns the created document ID.
  static Future<String> createSwap(String listingId, String requesterId, String ownerId) async {
    final col = FirebaseFirestore.instance.collection('swaps');
    final doc = await col.add({
      'listingId': listingId,
      'requesterId': requesterId,
      'ownerId': ownerId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Listen to swaps for a specific listing.
  static Stream<List<Map<String, dynamic>>> listenSwapsForListing(String listingId) {
    final col = FirebaseFirestore.instance.collection('swaps').where('listingId', isEqualTo: listingId).orderBy('createdAt', descending: false);
    return _queryToListStream(col);
  }

  /// Accept a swap by setting status to 'accepted'.
  static Future<void> acceptSwap(String swapId) async {
    final ref = FirebaseFirestore.instance.collection('swaps').doc(swapId);
    await ref.update({'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()});
  }

  /// Get count of listings owned by a user.
  static Future<int> getUserListingCount(String uid) async {
    final snap = await FirebaseFirestore.instance.collection('listings').where('ownerId', isEqualTo: uid).get();
    return snap.size;
  }

  /// Get a summary of swaps for a user.
  static Future<Map<String, int>> getUserSwapSummary(String uid) async {
    final requestedSnap = await FirebaseFirestore.instance.collection('swaps').where('requesterId', isEqualTo: uid).get();
    final receivedSnap = await FirebaseFirestore.instance.collection('swaps').where('ownerId', isEqualTo: uid).get();
    final acceptedSnap = await FirebaseFirestore.instance.collection('swaps').where('status', isEqualTo: 'accepted').where('ownerId', isEqualTo: uid).get();
    return {
      'requested': requestedSnap.size,
      'received': receivedSnap.size,
      'accepted': acceptedSnap.size,
    };
  }

  /// Get recent swap history for a user (both requested and owned).
  static Future<List<Map<String, dynamic>>> getUserSwapHistory(String uid, {int limit = 20}) async {
    final col = FirebaseFirestore.instance.collection('swaps').where('requesterId', isEqualTo: uid);
    final col2 = FirebaseFirestore.instance.collection('swaps').where('ownerId', isEqualTo: uid);
    final snaps = await Future.wait([col.orderBy('createdAt', descending: true).limit(limit).get(), col2.orderBy('createdAt', descending: true).limit(limit).get()]);
    final combined = <Map<String, dynamic>>[];
    for (final s in snaps) {
      for (final d in s.docs) {
        final m = d.data();
        m['id'] = d.id;
        combined.add(m);
      }
    }
    combined.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0;
      final tb = (b['createdAt'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return combined.take(limit).toList();
  }

  /// Fetch multiple listings by their document IDs and return a map id->data.
  static Future<Map<String, Map<String, dynamic>>> getListingsByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    // Firestore `whereIn` supports up to 10 items; batch if necessary.
    final Map<String, Map<String, dynamic>> result = {};
    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize) > ids.length ? ids.length : i + chunkSize);
      final snap = await FirebaseFirestore.instance.collection('listings').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final m = d.data();
        m['id'] = d.id;
        result[d.id] = Map<String, dynamic>.from(m);
      }
    }
    return result;
  }

  /// Create a minimal user profile document for newly registered users.
  /// This stores displayName and optional avatarUrl under `users/{uid}`.
  static Future<void> createUserProfile(String uid, {String? displayName, String? avatarUrl}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final payload = <String, dynamic>{
      'displayName': displayName ?? '',
      'avatarUrl': avatarUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(payload, SetOptions(merge: true));
  }

  /// Batch fetch user profiles by uid. Returns map uid -> user doc data.
  static Future<Map<String, Map<String, dynamic>>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final Map<String, Map<String, dynamic>> result = {};
    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize) > ids.length ? ids.length : i + chunkSize);
      final snap = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final m = d.data();
        result[d.id] = Map<String, dynamic>.from(m);
      }
    }
    return result;
  }

  /// Get all listings for a given user (ownerId == uid).
  static Future<List<Map<String, dynamic>>> getListingsForUser(String uid) async {
    final snap = await FirebaseFirestore.instance.collection('listings').where('ownerId', isEqualTo: uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();
  }

  /// Update a listing document.
  static Future<void> updateListing(String listingId, Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance.collection('listings').doc(listingId);
    await ref.update(data);
  }

  /// Delete a listing document by id.
  static Future<void> deleteListing(String listingId) async {
    final ref = FirebaseFirestore.instance.collection('listings').doc(listingId);
    await ref.delete();
  }

  /// Get a single listing by id. Returns null if not found.
  static Future<Map<String, dynamic>?> getListingById(String listingId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('listings').doc(listingId);
      final snap = await ref.get();
      if (!snap.exists) return null;
      final m = Map<String, dynamic>.from(snap.data()!);
      m['id'] = snap.id;
      return m;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] getListingById error: $e');
      rethrow;
    }
  }

  /// Get a single user profile by uid. Returns null if not found.
  static Future<Map<String, dynamic>?> getUserById(String uid) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) return null;
      final m = Map<String, dynamic>.from(snap.data()!);
      m['id'] = snap.id;
      return m;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] getUserById error: $e');
      rethrow;
    }
  }

  /// Update a user profile (merge). Useful for editing displayName/avatar and other fields.
  static Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] updateUserProfile error: $e');
      rethrow;
    }
  }

  /// Listen to listings for a specific user (ownerId == uid).
  static Stream<List<Map<String, dynamic>>> listenUserListings(String uid) {
    final col = FirebaseFirestore.instance.collection('listings').where('ownerId', isEqualTo: uid).orderBy('createdAt', descending: true);
    return _queryToListStream(col);
  }

  /// Create a chat document with an explicit participants list. Returns the created chat id.
  /// Use this when you need a non-deterministic chat id (group chat etc.).
  static Future<String> createChatWithParticipants(List<String> participants, {String? chatId, Map<String, dynamic>? metadata}) async {
    if (participants.isEmpty) throw ArgumentError('participants must not be empty');
    try {
      final col = FirebaseFirestore.instance.collection('chats');
      if (chatId != null && chatId.isNotEmpty) {
        final ref = col.doc(chatId);
        final payload = <String, dynamic>{
          'participants': participants,
          'lastMessage': '',
          'lastSentAt': FieldValue.serverTimestamp(),
        };
        if (metadata != null) payload.addAll(metadata);
        await ref.set(payload, SetOptions(merge: true));
        return ref.id;
      } else {
        final docRef = await col.add({
          'participants': participants,
          'lastMessage': '',
          'lastSentAt': FieldValue.serverTimestamp(),
          if (metadata != null) ...metadata,
        });
        return docRef.id;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] createChatWithParticipants error: $e');
      rethrow;
    }
  }

  /// Delete a chat and its messages subcollection in batches.
  /// Use with caution (destructive). This method paginates deletes to avoid
  /// exceeding batch limits.
  static Future<void> deleteChat(String chatId) async {
    final firestore = FirebaseFirestore.instance;
    final chatRef = firestore.collection('chats').doc(chatId);
    try {
      // Delete messages in batches of up to 500
      const batchSize = 500;
      while (true) {
        final msgs = await chatRef.collection('messages').limit(batchSize).get();
        if (msgs.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final d in msgs.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (msgs.docs.length < batchSize) break;
      }
      // Delete the chat doc itself
      await chatRef.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] deleteChat error: $e');
      rethrow;
    }
  }

  /// Get a swap by id. Returns null if not found.
  static Future<Map<String, dynamic>?> getSwapById(String swapId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('swaps').doc(swapId);
      final snap = await ref.get();
      if (!snap.exists) return null;
      final m = Map<String, dynamic>.from(snap.data()!);
      m['id'] = snap.id;
      return m;
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] getSwapById error: $e');
      rethrow;
    }
  }

  /// Delete a swap by id.
  static Future<void> deleteSwap(String swapId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('swaps').doc(swapId);
      await ref.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[FirebaseService] deleteSwap error: $e');
      rethrow;
    }
  }

  // ----------------- Chat / Messaging -----------------

  /// Deterministic chat id for a direct 1:1 chat between two users.
  /// We use a stable doc id by sorting the two uids and joining with an underscore.
  static String _directChatId(String a, String b) {
    final parts = [a, b]..sort();
    return parts.join('_');
  }

  /// Get or create a direct chat document between two users. Returns the chatId.
  static Future<String> getOrCreateDirectChat(String uidA, String uidB) async {
    final id = _directChatId(uidA, uidB);
    final ref = FirebaseFirestore.instance.collection('chats').doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [uidA, uidB],
        'lastMessage': '',
        'lastSentAt': FieldValue.serverTimestamp(),
      });
    }
    return ref.id;
  }

  /// Send a message to a chat. Adds a message doc under chats/{chatId}/messages
  /// and updates the chat doc's lastMessage/lastSentAt fields.
  static Future<void> sendMessage(String chatId, String senderId, {String? text, String? imageUrl}) async {
    // Prevent sending entirely empty messages. Require at least text or an image.
    final t = text?.trim() ?? '';
    final i = imageUrl?.trim() ?? '';
    if (t.isEmpty && i.isEmpty) {
      throw ArgumentError('Cannot send empty message: provide text and/or imageUrl');
    }

    final messagesRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages');
    final payload = <String, dynamic>{
      'senderId': senderId,
      'text': t,
      'imageUrl': i,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await messagesRef.add(payload);

    // Update chat metadata
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await chatRef.update({
      'lastMessage': (t.isNotEmpty ? t : (i.isNotEmpty ? '[image]' : '')),
      'lastSentAt': FieldValue.serverTimestamp(),
    });
    return;
  }

  /// Listen to messages for a chat ordered by createdAt ascending.
  static Stream<List<Map<String, dynamic>>> listenMessages(String chatId) {
    final ref = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('createdAt', descending: false);
    return _queryToListStream(ref);
  }

  /// Listen to chats for a user (where participants contains uid), ordered by lastSentAt desc.
  static Stream<List<Map<String, dynamic>>> listenChatsForUser(String uid) {
    final ref = FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: uid).orderBy('lastSentAt', descending: true);
    return _queryToListStream(ref);
  }

  /// Internal helper which converts a Firestore Query snapshots stream into
  /// a Stream<List<Map<String,dynamic>>> with error handling and logging.
  /// On listen errors (for example permissions or malformed requests) the
  /// stream will emit an empty list and log the error to debug output so the
  /// UI can continue to operate instead of crashing the app.
  static Stream<List<Map<String, dynamic>>> _queryToListStream(Query query) {
    // Capture a brief description of the query for diagnostics. Prefer the
    // collection path when possible; otherwise fall back to toString().
    String queryDesc;
    try {
      if (query is CollectionReference) {
        // Promoted inside the if to access .path without a cast.
        queryDesc = query.path;
      } else {
        queryDesc = query.toString();
      }
    } catch (_) {
      queryDesc = query.toString();
    }

    // Use a StreamTransformer to catch errors and map QuerySnapshot -> List<Map>
    return query.snapshots().transform(
      StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<Map<String, dynamic>>>.fromHandlers(
        handleData: (snap, sink) {
          try {
            final list = snap.docs.map((d) {
              final m = Map<String, dynamic>.from(d.data());
              m['id'] = d.id;
              return m;
            }).toList();
            sink.add(list);
          } catch (e, st) {
            if (kDebugMode) debugPrint('[FirebaseService] snapshot->map error: $e\n$st');
            sink.add([]);
          }
        },
        handleError: (err, st, sink) {
          // Emit diagnostic information to help identify auth/project/rules issues.
          try {
            final user = FirebaseAuth.instance.currentUser;
            final active = Firebase.app();
            final opts = active.options;
            if (kDebugMode) {
              debugPrint('[FirebaseService] Firestore listen error: $err');
              debugPrint('$st');
              debugPrint('[FirebaseService] Query: $queryDesc');
              debugPrint('[FirebaseService] kIsWeb: $kIsWeb');
              debugPrint('[FirebaseService] Active app projectId=${opts.projectId}, apiKey=${opts.apiKey}, appId=${opts.appId}, authDomain=${opts.authDomain}');
              debugPrint('[FirebaseService] Current user uid=${user?.uid ?? 'null'}, email=${user?.email ?? 'null'}');
            }
          } catch (e) {
            if (kDebugMode) debugPrint('[FirebaseService] Failed to print diagnostics: $e');
          }

          // If the error is a permission denied error, forward it to listeners
          // so UI can display a helpful message instead of silently showing
          // an empty list. Otherwise emit an empty list as a fallback.
          try {
            if (err is FirebaseException && err.code == 'permission-denied') {
              sink.addError(FirebaseException(
                plugin: 'cloud_firestore',
                message: 'Permission denied reading Firestore. Check rules and whether the user is signed in.',
              ), st);
              return;
            }
          } catch (_) {}
          try {
            sink.add([]);
          } catch (_) {}
        },
      ),
    );
  }

  /// Upload an image for chat (returns download URL).
  static Future<String> uploadChatImage(File localFile, Function(double)? onProgress) async {
    final storage = FirebaseStorage.instance;
    final id = const Uuid().v4();
    final ref = storage.ref().child('chat_images').child('$id.jpg');
    final uploadTask = ref.putFile(localFile);

    uploadTask.snapshotEvents.listen((event) {
      final bytesTransferred = event.bytesTransferred.toDouble();
      final totalBytes = event.totalBytes.toDouble();
      final progress = (totalBytes > 0) ? (bytesTransferred / totalBytes) : 0.0;
      if (onProgress != null) onProgress(progress.clamp(0.0, 1.0));
    });

    final snap = await uploadTask;
    final url = await snap.ref.getDownloadURL();
    return url;
  }

  /// Return a human-readable diagnostics string useful for reporting listen
  /// failures. Optionally include a query description and the original error.
  static Future<String> getDiagnostics({String? queryDesc, Object? error}) async {
    final sb = StringBuffer();
    sb.writeln('timestamp: ${DateTime.now().toIso8601String()}');
    sb.writeln('kIsWeb: $kIsWeb');
    try {
      final active = Firebase.app();
      final opts = active.options;
      sb.writeln('activeApp: ${active.name}');
      sb.writeln('projectId: ${opts.projectId}');
      sb.writeln('apiKey: ${opts.apiKey}');
      sb.writeln('appId: ${opts.appId}');
      sb.writeln('authDomain: ${opts.authDomain}');
    } catch (e) {
      sb.writeln('failed to read Firebase.app(): $e');
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      sb.writeln('currentUser.uid: ${user?.uid ?? 'null'}');
      sb.writeln('currentUser.email: ${user?.email ?? 'null'}');
    } catch (e) {
      sb.writeln('failed to read FirebaseAuth.currentUser: $e');
    }
    if (queryDesc != null) sb.writeln('query: $queryDesc');
    if (error != null) sb.writeln('error: $error');
    return sb.toString();
  }
}
