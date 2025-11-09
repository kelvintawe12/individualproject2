import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

// Simple AppCubit to hold shell-level UI state (selected tab index).
// Start simple: the state is an int representing the selected bottom nav index.
class AppCubit extends Cubit<int> {
  AppCubit([int initialIndex = 0]) : super(initialIndex);

  void setIndex(int index) => emit(index);

  /// Convenience to switch to a named slot (if you want more semantic methods)
  void goToBrowse() => setIndex(0);
  void goToLibrary() => setIndex(1);
  void goToChats() => setIndex(2);
  void goToNotifications() => setIndex(3);
  void goToSettings() => setIndex(4);
}
