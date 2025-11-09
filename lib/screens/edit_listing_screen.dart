import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for haptics
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';

class EditListingScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _swapForCtrl;
  late TextEditingController _imageUrlCtrl;

  String _condition = 'New';
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _customImageUrl;
  bool _loading = false;
  bool _uploadingImage = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.listing['title'] ?? '');
    _authorCtrl = TextEditingController(text: widget.listing['author'] ?? '');
    _swapForCtrl = TextEditingController(text: widget.listing['swapFor'] ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.listing['imageUrl'] ?? '');
    _condition = widget.listing['condition'] ?? 'New';
    _customImageUrl = widget.listing['imageUrl'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _swapForCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  // ========================================
  // MOVED THESE UP — FIXES ALL ERRORS
  // ========================================
  void _showSnack(String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0B429), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null
          : null,
    );
  }

  // ========================================
  // IMAGE PICKER — NOW WITH CAMERA TOO
  // ========================================
  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() => _uploadingImage = true);

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = null;
          _customImageUrl = null;
          _imageUrlCtrl.text = '';
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
          _imageBytes = null;
          _customImageUrl = null;
          _imageUrlCtrl.text = '';
        });
      }
    } catch (e) {
      _showSnack('Image pick failed: $e', success: false);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ========================================
  // IMAGE PREVIEW
  // ========================================
  Widget _buildImagePreview() {
    Widget child;

    if (_uploadingImage) {
      child = const Center(child: CircularProgressIndicator(color: Color(0xFFF0B429)));
    } else if (_imageBytes != null) {
      child = Image.memory(_imageBytes!, fit: BoxFit.cover);
    } else if (_imageFile != null) {
      child = Image.file(_imageFile!, fit: BoxFit.cover);
    } else if (_customImageUrl != null && _customImageUrl!.isNotEmpty) {
      child = Image.network(
        _customImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const CircularProgressIndicator(strokeWidth: 3),
        errorBuilder: (_, __, ___) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.redAccent, size: 48),
            Text('Invalid URL', style: TextStyle(color: Colors.red[300])),
          ],
        ),
      );
    } else {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_rounded, size: 64, color: Colors.white38),
          SizedBox(height: 12),
          Text('No image selected', style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(_imageBytes ?? _imageFile ?? _customImageUrl),
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white10,
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: child,
        ),
      ),
    );
  }

  // ========================================
  // SAVE CHANGES
  // ========================================
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      String? finalImageUrl = widget.listing['imageUrl'];

      if (_imageFile != null) {
        finalImageUrl = await FirebaseService.uploadImage(_imageFile!, null);
      } else if (_imageBytes != null) {
        finalImageUrl = await FirebaseService.uploadImageBytes(_imageBytes!, null);
      } else if (_customImageUrl != null &&
          _customImageUrl != widget.listing['imageUrl'] &&
          Uri.tryParse(_customImageUrl!)?.hasScheme == true) {
        finalImageUrl = _customImageUrl;
      }

      final updatedData = {
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim(),
        'swapFor': _swapForCtrl.text.trim(),
        'condition': _condition,
        if (finalImageUrl != null) 'imageUrl': finalImageUrl,
      };

      await FirebaseService.updateListing(widget.listing['id'], updatedData);

      if (mounted) {
        Navigator.pop(context);
        _showSnack('🎉 Listing updated perfectly!', success: true);
      }
    } catch (e) {
      _showSnack('Update failed: $e', success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ========================================
  // BUILD
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Listing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _loading ? null : _saveChanges,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1724), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 70),

                // Image Preview
                Center(child: _buildImagePreview()),
                const SizedBox(height: 20),

                // Image Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 22),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFF0B429), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _uploadingImage ? null : () => _pickImage(),
                        onLongPress: _uploadingImage ? null : () => _pickImage(fromCamera: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 22),
                        label: const Text('URL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyan,
                          side: const BorderSide(color: Colors.cyan, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Paste Image URL', style: TextStyle(color: Colors.white)),
                            content: TextField(
                              controller: _imageUrlCtrl,
                              decoration: InputDecoration(
                                hintText: 'https://example.com/cover.jpg',
                                hintStyle: const TextStyle(color: Colors.white38),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white38),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFF0B429)),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.url,
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
                                onPressed: () {
                                  final url = _imageUrlCtrl.text.trim();
                                  if (url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true) {
                                    setState(() {
                                      _customImageUrl = url;
                                      _imageFile = null;
                                      _imageBytes = null;
                                    });
                                    Navigator.pop(context);
                                  } else {
                                    _showSnack('Please enter a valid URL', success: false);
                                  }
                                },
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Form Fields
                _buildTextField(_titleCtrl, 'Book Title', required: true),
                const SizedBox(height: 16),
                _buildTextField(_authorCtrl, 'Author', required: true),
                const SizedBox(height: 16),
                _buildTextField(_swapForCtrl, 'What do you want in swap? (optional)', maxLines: 3),
                const SizedBox(height: 28),

                // Condition Chips
                const Text('Condition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: ['New', 'Like New', 'Good', 'Used'].map((c) {
                    final selected = c == _condition;
                    return FilterChip(
                      label: Text(c),
                      selected: selected,
                      selectedColor: const Color(0xFFF0B429),
                      backgroundColor: Colors.white12,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      avatar: selected ? const Icon(Icons.check, size: 18) : null,
                      shape: StadiumBorder(side: BorderSide(color: selected ? const Color(0xFFF0B429) : Colors.white24)),
                      onSelected: (_) => setState(() => _condition = c),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _loading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF0B429),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Update Listing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}