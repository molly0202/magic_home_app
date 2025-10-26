import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WorkShowcaseEditScreen extends StatefulWidget {
  final String providerId;

  const WorkShowcaseEditScreen({
    super.key,
    required this.providerId,
  });

  @override
  State<WorkShowcaseEditScreen> createState() => _WorkShowcaseEditScreenState();
}

class _WorkShowcaseEditScreenState extends State<WorkShowcaseEditScreen> {
  List<File> _newPhotos = [];
  List<String> _existingPhotoUrls = [];
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();
      
      final data = providerDoc.data();
      setState(() {
        _existingPhotoUrls = List<String>.from(data?['workShowcasePhotos'] ?? []);
      });
    } catch (e) {
      print('Error loading photos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Work Showcase'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFFBB04C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Showcase Your Work',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add photos of your previous work to build trust with customers.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            
            // Add photo button
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 48, color: Color(0xFFFBB04C)),
                    SizedBox(height: 8),
                    Text(
                      'Add Work Photos',
                      style: TextStyle(
                        color: Color(0xFFFBB04C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Photo grid
            if (_existingPhotoUrls.isNotEmpty || _newPhotos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _existingPhotoUrls.length + _newPhotos.length,
                itemBuilder: (context, index) {
                  final isExisting = index < _existingPhotoUrls.length;
                  
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isExisting
                              ? Image.network(
                                  _existingPhotoUrls[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : Image.file(
                                  _newPhotos[index - _existingPhotoUrls.length],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            if (isExisting) {
                              _removeExistingPhoto(index);
                            } else {
                              _removeNewPhoto(index - _existingPhotoUrls.length);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            
            const SizedBox(height: 16),
            Text(
              '${_existingPhotoUrls.length + _newPhotos.length}/10 photos',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_existingPhotoUrls.length + _newPhotos.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 photos allowed')),
      );
      return;
    }

    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Add Work Photo'),
            content: const Text('Choose how to add a photo of your work:'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (source != null) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );

        if (pickedFile != null) {
          setState(() {
            _newPhotos.add(File(pickedFile.path));
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo added! Save to upload.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Photo picker error: $e');
      
      // Show user-friendly error message
      String errorMessage = 'Unable to access photos.';
      if (e.toString().contains('camera_access_denied')) {
        errorMessage = 'Camera access denied. Please enable camera access in Settings → Privacy & Security → Camera → Magic Home App.';
      } else if (e.toString().contains('photo_access_denied')) {
        errorMessage = 'Photo library access denied. Please enable photo access in Settings → Privacy & Security → Photos → Magic Home App.';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Access Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 12),
              const Text(
                'To fix this:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('1. Go to iPhone Settings'),
              const Text('2. Privacy & Security → Camera/Photos'),
              const Text('3. Find "Magic Home App"'),
              const Text('4. Enable access'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Upload new photos
      List<String> newPhotoUrls = [];
      for (var photo in _newPhotos) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('providers')
            .child(widget.providerId)
            .child('showcase')
            .child('${DateTime.now().millisecondsSinceEpoch}_${newPhotoUrls.length}.jpg');

        final uploadTask = storageRef.putFile(photo);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        newPhotoUrls.add(downloadUrl);
      }

      // Combine existing and new photos
      final allPhotoUrls = [..._existingPhotoUrls, ...newPhotoUrls];

      // Update database
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .update({
        'workShowcasePhotos': allPhotoUrls,
        'showcaseUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work showcase updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save photos: $e';
        _isLoading = false;
      });
    }
  }
}
