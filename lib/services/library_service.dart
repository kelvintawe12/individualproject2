import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'firebase_service.dart';

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

  /// Listen to user's library listings with full listing data.
  static Stream<List<Map<String, dynamic>>> listenUserLibraryListings(String userId) {
    // We must preserve the order of the user's library entries and also
    // merge the library entry's `addedAt` timestamp into the listing map
    // so UI code can show when the user added the listing to their library.
    return listenUserLibrary(userId).asyncMap((entries) async {
      final ids = entries.map((e) => e['listingId'] as String).toList();
      if (ids.isEmpty) return [];
      final listingsMap = await FirebaseService.getListingsByIds(ids);

      final List<Map<String, dynamic>> merged = [];
      for (final entry in entries) {
        final listingId = entry['listingId'] as String?;
        if (listingId == null) continue;
        final listing = listingsMap[listingId];
        if (listing == null) {
          // Listing was removed/deleted — skip it
          continue;
        }

        // Create a shallow copy and inject the library `addedAt` as
        // `timestamp` (UI expects `timestamp` to determine "time ago").
        final mergedListing = Map<String, dynamic>.from(listing);
        if (entry.containsKey('addedAt')) {
          mergedListing['timestamp'] = entry['addedAt'];
        } else if (!mergedListing.containsKey('timestamp') && mergedListing.containsKey('createdAt')) {
          // Fallback to listing's createdAt if no addedAt present
          mergedListing['timestamp'] = mergedListing['createdAt'];
        }

        merged.add(mergedListing);
      }

      return merged;
    });
  }
}
