import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  String _condition = 'New';
  File? _imageFile;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      _showError('Image picker failed: $e');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _confirmAndPost() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Post'),
        content: const Text('Are you sure you want to post this listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Post')),
        ],
      ),
    );

    if (confirm != true) return;

    // Show upload progress dialog
    showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          content: SizedBox(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 12),
                Text('Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%')
              ],
            ),
          ),
        );
      }),
    );

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await FirebaseService.uploadImage(_imageFile!, (p) {
          _uploadProgress = p;
          // rebuild the top-most dialog
          setState(() {});
        });
      } else {
        // small delay when no image
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // create listing in Firestore
      final ownerId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      await FirebaseService.createListing({
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim(),
        'condition': _condition,
        'imageUrl': imageUrl,
        'ownerId': ownerId,
      });

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      } else {
        return;
      }

      // Show success Lottie dialog
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 150, height: 150, child: Lottie.network('https://assets10.lottiefiles.com/packages/lf20_jbrw3hcz.json')),
              const SizedBox(height: 8),
              const Text('Listing posted!')
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
        ),
      );

      // Pop PostScreen and show a snackbar
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted (mock)')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showError('Upload failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Book'),
        backgroundColor: const Color(0xFF0F1724),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Book Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a book title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorCtrl,
                decoration: const InputDecoration(labelText: 'Author'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the author' : null,
              ),
              const SizedBox(height: 12),
              const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['New', 'Like New', 'Good', 'Used'].map((c) {
                  final selected = c == _condition;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      selected: selected,
                      selectedColor: const Color(0xFFF0B429),
                      backgroundColor: Colors.grey[200],
                      onSelected: (_) => setState(() => _condition = c),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo),
                    label: const Text('Choose Image'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F1724)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _imageFile == null
                          ? const Text('No image selected', style: TextStyle(color: Colors.grey))
                          : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, height: 80, fit: BoxFit.cover)),
                    ),
                  )
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _confirmAndPost,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Post', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
