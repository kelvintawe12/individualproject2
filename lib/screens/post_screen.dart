import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({Key? key}) : super(key: key);

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _swapForCtrl = TextEditingController();
  String _condition = 'Like New';
  bool _isLibraryBook = false;
  File? _imageFile;
  Uint8List? _imageBytes; // for web
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  Animation<double> _fadeAnimation = AlwaysStoppedAnimation<double>(1.0);
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _swapForCtrl.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          setState(() {
            _imageFile = File(picked.path);
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      _showSnack('Image picker failed');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmAndPost() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(),
    );
    if (confirm != true) return;

    // Show upload dialog (use ValueNotifier so the dialog updates while upload runs)
    final progressNotifier = ValueNotifier<double>(_uploadProgress);
    // show dialog without awaiting so upload can proceed
    showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (_) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (ctx, p, _) => _UploadProgressDialog(progress: p),
      ),
    );

    try {
      String? imageUrl;
      if (_imageFile != null) {
        debugPrint('[PostScreen] Starting image upload...');
        try {
          imageUrl = await FirebaseService.uploadImage(_imageFile!, (p) {
            // update the notifier so the dialog reflects progress
            progressNotifier.value = p;
            debugPrint('[PostScreen] upload progress: ${(p * 100).toStringAsFixed(1)}%');
          }).timeout(const Duration(seconds: 45), onTimeout: () {
            throw TimeoutException('Image upload timed out after 45s');
          });
          debugPrint('[PostScreen] upload finished, imageUrl=$imageUrl');
        } on TimeoutException catch (t) {
          debugPrint('[PostScreen] upload timeout: $t');
          rethrow;
        }
      }

      final ownerId = _isLibraryBook ? 'library' : (FirebaseAuth.instance.currentUser?.uid ?? 'anonymous');
      final listingData = {
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim(),
        'condition': _condition,
        'swapFor': _swapForCtrl.text.trim(),
        'imageUrl': imageUrl,
        'ownerId': ownerId,
        'type': _isLibraryBook ? 'library' : 'user',
        'timestamp': DateTime.now(),
      };
      debugPrint('[PostScreen] creating listing with data: $listingData');
      // create listing with timeout and logging
      await FirebaseService.createListing(listingData).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('createListing timed out after 15s');
      });
      debugPrint('[PostScreen] createListing succeeded');

  if (!mounted) return;
  // close progress dialog
  Navigator.of(context).pop();
  progressNotifier.dispose();

      await showDialog<void>(
        context: context,
        builder: (_) => _SuccessDialog(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // close PostScreen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book posted!')));
      }
    } catch (e) {
      if (mounted) {
        // close progress dialog and show error
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        progressNotifier.dispose();
        _showSnack('Failed to post: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1724),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Post a Book',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F1724),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: bottomInset + 100, top: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Preview Card
                            if (_titleCtrl.text.isNotEmpty || _imageFile != null || _imageBytes != null)
                              _BookPreviewCard(
                                title: _titleCtrl.text,
                                author: _authorCtrl.text,
                                condition: _condition,
                                swapFor: _swapForCtrl.text,
                                imageFile: _imageFile,
                                imageBytes: _imageBytes,
                              ),
                            const SizedBox(height: 16),

                            // Form Fields
                            _GlassTextField(controller: _titleCtrl, label: 'Book Title', icon: Icons.book),
                            const SizedBox(height: 12),
                            _GlassTextField(controller: _authorCtrl, label: 'Author', icon: Icons.person),
                            const SizedBox(height: 12),
                            _GlassTextField(controller: _swapForCtrl, label: 'Swap-For (optional)', icon: Icons.swap_horiz),
                            const SizedBox(height: 16),

                            // Condition Chips
                            const Text('Condition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: ['New', 'Like New', 'Good', 'Used'].map((c) {
                                final selected = c == _condition;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setState(() => _condition = c),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selected ? const Color(0xFFF0B429) : const Color(0xFF0B1220).withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: selected ? Colors.transparent : Colors.white38, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (selected) ...[
                                            const Icon(Icons.check, size: 16, color: Colors.black87),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            c,
                                            style: TextStyle(
                                              color: selected ? Colors.black87 : Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Library Book Toggle
                            Row(
                              children: [
                                const Text('Post as Library Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Switch(
                                  value: _isLibraryBook,
                                  onChanged: (value) => setState(() => _isLibraryBook = value),
                                  activeColor: const Color(0xFFF0B429),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Image Picker
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.photo_library, color: Colors.white),
                                  label: const Text('Add Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: (_imageBytes == null && _imageFile == null)
                                        ? const Text('No photo selected', style: TextStyle(color: Colors.white60))
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: _imageBytes != null
                                                ? Image.memory(_imageBytes!, height: 80, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => Container(width: 80, height: 80, color: Colors.grey[800]))
                                                : Image.file(_imageFile!, height: 80, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => Container(width: 80, height: 80, color: Colors.grey[800])),
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Push remaining content to bottom
                            const Spacer(),

                            // Post Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _confirmAndPost,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0B429),
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Text('Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(currentIndex: 1),
    );
  }
}

// ── Glass TextField ─────────────────────────────────────
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _GlassTextField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: Icon(icon, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: InputBorder.none,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF0B429), width: 2),
            ),
          ),
          validator: (v) => (label.contains('Title') || label.contains('Author')) && (v?.trim().isEmpty ?? true)
              ? 'Required'
              : null,
        ),
      ),
    );
  }
}

// ── Book Preview Card ─────────────────────────────────────
class _BookPreviewCard extends StatelessWidget {
  final String title;
  final String author;
  final String condition;
  final String swapFor;
  final File? imageFile;
  final Uint8List? imageBytes;

  const _BookPreviewCard({
    required this.title,
    required this.author,
    required this.condition,
    required this.swapFor,
    this.imageFile,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageBytes != null
                      ? Image.memory(imageBytes!, width: 70, height: 90, fit: BoxFit.cover)
                      : (imageFile != null
                          ? Image.file(imageFile!, width: 70, height: 90, fit: BoxFit.cover)
                          : Container(
                              width: 70,
                              height: 90,
                              color: Colors.grey[800],
                              child: const Icon(Icons.book, color: Colors.white70, size: 32),
                            )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Untitled' : title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'By ${author.isEmpty ? 'Unknown' : author}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ConditionBadge(condition: condition),
                          const SizedBox(width: 8),
                          const Text('3 days ago', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                      if (swapFor.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Swap-For: $swapFor',
                          style: const TextStyle(color: Color(0xFFF0B429), fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Condition Badge ─────────────────────────────────────
class _ConditionBadge extends StatelessWidget {
  final String condition;
  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final isNew = condition.toLowerCase().contains('new');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNew ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isNew ? Colors.green : Colors.orange, width: 1),
      ),
      child: Text(
        condition,
        style: TextStyle(color: isNew ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ── Confirm Dialog ─────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirm Post'),
      content: const Text('Are you sure you want to post this listing?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0B429)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Post', style: TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }
}

// ── Upload Progress Dialog ─────────────────────────────────────
class _UploadProgressDialog extends StatelessWidget {
  final double progress;
  const _UploadProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress, color: const Color(0xFFF0B429)),
          const SizedBox(height: 16),
          Text('${(progress * 100).toStringAsFixed(0)}% Uploading...'),
        ],
      ),
    );
  }
}

// ── Success Dialog ─────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset('assets/confetti.json', width: 120, height: 120, repeat: false),
          const Text('Listing posted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  const _BottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: const Color(0xFF0F1724),
      unselectedItemColor: Colors.white60,
      selectedItemColor: const Color(0xFFF0B429),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Post'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
      ],
      onTap: (i) {
        if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      ),
    );
  }
}