 import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class LibraryService {
  /// Add a listing to the user's library.
  static Future<void> addToLibrary(String userId, String listingId) async {
    final ref = FirebaseFirestore.instance.collection('libraries').doc('${userId}_$listingId');
    await ref.set({
      'userId': userId,
      'listingId': listingId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a listing from the user's library.
  static Future<void> removeFromLibrary(String userId, String listingId) async {
    final ref = FirebaseFirestore.instance.collection('libraries').doc('${userId}_$listingId');
    await ref.delete();
  }

  /// Check if a listing is in the user's library.
  static Future<bool> isInLibrary(String userId, String listingId) async {
    final ref = FirebaseFirestore.instance.collection('libraries').doc('${userId}_$listingId');
    final snap = await ref.get();
    return snap.exists;
  }

  /// Listen to user's library listings.
  static Stream<List<Map<String, dynamic>>> listenUserLibrary(String userId) {
    final col = FirebaseFirestore.instance.collection('libraries').where('userId', isEqualTo: userId).orderBy('addedAt', descending: true);
    return col.snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
    });
  }
}
