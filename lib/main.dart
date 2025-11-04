import 'package:flutter/material.dart';
import 'app.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (stubbed). Replace with real Firebase init when configured.
  await FirebaseService.initialize();
  runApp(const BookSwapApp());
}
