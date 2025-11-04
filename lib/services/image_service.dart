import 'dart:io';

class ImageService {
  /// Stubbed upload method. Replace with Firebase Storage upload logic.
  static Future<String> uploadImage(File file, Function(double)? onProgress) async {
    // Simulate upload progress
    const totalSteps = 5;
    for (var i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      onProgress?.call(i / totalSteps);
    }

    // Return a mock download URL
    return 'https://example.com/uploads/${DateTime.now().millisecondsSinceEpoch}.png';
  }
}
