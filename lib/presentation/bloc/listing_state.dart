class ListingState {
  final bool inLibrary;
  final bool isPending;
  final bool isAccepted;
  final bool libLoading;

  const ListingState({this.inLibrary = false, this.isPending = false, this.isAccepted = false, this.libLoading = false});

  ListingState copyWith({bool? inLibrary, bool? isPending, bool? isAccepted, bool? libLoading}) {
    return ListingState(
      inLibrary: inLibrary ?? this.inLibrary,
      isPending: isPending ?? this.isPending,
      isAccepted: isAccepted ?? this.isAccepted,
      libLoading: libLoading ?? this.libLoading,
    );
  }
}
