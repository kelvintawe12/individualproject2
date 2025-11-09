import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import '../../services/library_service.dart';
import '../../services/firebase_service.dart';
import 'listing_state.dart';

/// ListingCubit manages per-listing small UI state that is shared across
/// listing widgets (bookmark/in-library, pending swap, loading indicator).
class ListingCubit extends Cubit<Map<String, ListingState>> {
  ListingCubit() : super(const {});

  ListingState _stateFor(String id) => state[id] ?? const ListingState();

  /// Load initial state for a listing (checks library membership and pending swaps)
  Future<void> loadInitial(String listingId) async {
    try {
      final current = _stateFor(listingId);
      // set a temporary state? we'll fetch both values and then emit
  final uid = FirebaseService.safeCurrentUid();
      if (uid == null) return;

      final inLib = await LibraryService.isInLibrary(uid, listingId);
      final pendingId = await FirebaseService.findPendingSwap(listingId, uid);
      final newState = current.copyWith(inLibrary: inLib, isPending: pendingId != null, isAccepted: false);
      emit({...state, listingId: newState});
    } catch (_) {
      // swallow errors to avoid crashing UI; keep previous state
    }
  }

  /// Toggle library membership for listing.
  Future<void> toggleInLibrary(String listingId) async {
    final cur = _stateFor(listingId);
  final uid = FirebaseService.safeCurrentUid();
    if (uid == null) return;
    // set loading
    emit({...state, listingId: cur.copyWith(libLoading: true)});
    try {
      if (!cur.inLibrary) {
        await LibraryService.addToLibrary(uid, listingId);
        emit({...state, listingId: cur.copyWith(inLibrary: true, libLoading: false)});
      } else {
        await LibraryService.removeFromLibrary(uid, listingId);
        emit({...state, listingId: cur.copyWith(inLibrary: false, libLoading: false)});
      }
    } catch (_) {
      // on error, reset loading flag but keep previous inLibrary
      emit({...state, listingId: cur.copyWith(libLoading: false)});
    }
  }

  /// Create a swap request (marks listing as pending for the requester)
  /// Returns the created swap document id or null on failure.
  Future<String?> createSwap(String listingId, String ownerId) async {
    final cur = _stateFor(listingId);
    final uid = FirebaseService.safeCurrentUid();
    if (uid == null) return null;
    try {
      final swapId = await FirebaseService.createSwap(listingId, uid, ownerId);
      emit({...state, listingId: cur.copyWith(isPending: true)});
      return swapId;
    } catch (_) {
      // leave state unchanged on failure
      return null;
    }
  }

  /// Mark this listing as accepted (e.g. owner accepted an offer).
  /// This will clear pending and set accepted flag so UI can react.
  void markAccepted(String listingId) {
    final cur = _stateFor(listingId);
    emit({...state, listingId: cur.copyWith(isPending: false, isAccepted: true)});
  }

  /// Clear any pending flag for a listing (used when user cancels an offer).
  void clearPending(String listingId) {
    final cur = _stateFor(listingId);
    emit({...state, listingId: cur.copyWith(isPending: false)});
  }
}
