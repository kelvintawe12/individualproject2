import 'dart:io';

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
    try {
      // Use generated Firebase options when available so web and all
      // platforms initialize correctly. For mobile, this will also read
      // native config files if present.
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      if (kDebugMode) debugPrint('Firebase initialized (with DefaultFirebaseOptions).');
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase initialization failed: $e');
      rethrow;
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
    return col.snapshots().map((snap) => snap.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList());
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
    return col.snapshots().map((snap) => snap.docs.map((d) {
          final m = d.data();
          m['id'] = d.id;
          return m;
        }).toList());
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
}
