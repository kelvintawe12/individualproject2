import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';

class EditListingScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const EditListingScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _swapForCtrl;
  late String _condition;
  File? _imageFile;
  Uint8List? _imageBytes;
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.listing['title'] ?? '');
    _authorCtrl = TextEditingController(text: widget.listing['author'] ?? '');
    _swapForCtrl = TextEditingController(text: widget.listing['swapFor'] ?? '');
    _condition = widget.listing['condition'] ?? 'New';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _swapForCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image picker failed: $e')));
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      String? imageUrl = widget.listing['imageUrl'];
      if (_imageFile != null) {
        imageUrl = await FirebaseService.uploadImage(_imageFile!, null);
      } else if (_imageBytes != null) {
        imageUrl = await FirebaseService.uploadImageBytes(_imageBytes!, null);
      }

      final updatedData = {
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim(),
        'swapFor': _swapForCtrl.text.trim(),
        'condition': _condition,
        'imageUrl': imageUrl,
      };

      await FirebaseService.updateListing(widget.listing['id'], updatedData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        backgroundColor: const Color(0xFF0F1724),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: _loading ? null : _saveChanges,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
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
              TextFormField(
                controller: _swapForCtrl,
                decoration: const InputDecoration(labelText: 'Swap-For (optional)'),
                validator: (v) => null,
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
                    label: const Text('Change Image'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F1724)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _imageBytes != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_imageBytes!, height: 80, fit: BoxFit.cover))
              : (_imageFile != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, height: 80, fit: BoxFit.cover))
                : (widget.listing['imageUrl'] != null)
                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.listing['imageUrl'], height: 80, fit: BoxFit.cover))
                  : const Text('No image', style: TextStyle(color: Colors.grey))),
          ),
                  )
                ],
              ),
              const Spacer(),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
