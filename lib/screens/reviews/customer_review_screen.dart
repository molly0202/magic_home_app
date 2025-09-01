import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/user_request.dart';
import '../../widgets/translatable_text.dart';

class CustomerReviewScreen extends StatefulWidget {
  final UserRequest task;
  final User user;

  const CustomerReviewScreen({
    Key? key,
    required this.task,
    required this.user,
  }) : super(key: key);

  @override
  State<CustomerReviewScreen> createState() => _CustomerReviewScreenState();
}

class _CustomerReviewScreenState extends State<CustomerReviewScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _reviewController = TextEditingController();
  
  int _currentPage = 0;
  List<File> _selectedImages = [];
  bool? _serviceExpectationsMet;
  bool? _wouldRecommend;
  bool _isSubmitting = false;
  Map<String, dynamic>? _providerData;
  bool _isLoadingProvider = true;
  bool _publishAnonymously = false;

  @override
  void initState() {
    super.initState();
    _reviewController.text = "I really enjoyed...";
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      if (widget.task.assignedProviderId != null) {
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.task.assignedProviderId!)
            .get();
        
        if (providerDoc.exists) {
          setState(() {
            _providerData = providerDoc.data();
            _isLoadingProvider = false;
          });
        } else {
          print('❌ Provider document not found: ${widget.task.assignedProviderId}');
          setState(() {
            _isLoadingProvider = false;
          });
        }
      } else {
        print('❌ No assigned provider ID found for task');
        setState(() {
          _isLoadingProvider = false;
        });
      }
    } catch (error) {
      print('❌ Error loading provider data: $error');
      setState(() {
        _isLoadingProvider = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromCamera();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: Color(0xFFFBB04C),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Camera',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 32,
                              color: Color(0xFFFBB04C),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 80,
    );
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)).toList());
      });
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<List<String>> _uploadPhotos() async {
    List<String> photoUrls = [];
    
    print('📸 Starting photo upload for ${_selectedImages.length} images');
    
    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final fileName = 'review_${widget.task.requestId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        print('📸 Uploading photo $i: $fileName');
        
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('review_photos')
            .child(fileName);
        
        final uploadTask = await storageRef.putFile(file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        photoUrls.add(downloadUrl);
        
        print('✅ Photo $i uploaded successfully: $downloadUrl');
      }
      
      print('📸 All photos uploaded successfully. URLs: $photoUrls');
    } catch (e) {
      print('❌ Error uploading photos: $e');
      // Continue without photos if upload fails
    }
    
    return photoUrls;
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload photos to Firebase Storage if any
      List<String> photoUrls = [];
      if (_selectedImages.isNotEmpty) {
        photoUrls = await _uploadPhotos();
      }

      // Create review document
      final reviewData = {
        'userId': widget.user.uid,
        'providerId': widget.task.assignedProviderId,
        'requestId': widget.task.requestId,
        'serviceCategory': widget.task.serviceCategory,
        'reviewText': _reviewController.text.trim(),
        'serviceExpectationsMet': _serviceExpectationsMet,
        'wouldRecommend': _wouldRecommend,
        'rating': _calculateOverallRating(),
        'createdAt': FieldValue.serverTimestamp(),
        'providerName': _providerData?['company'] ?? _providerData?['name'] ?? 'Unknown Provider',
        'serviceDate': DateTime.now().toIso8601String().split('T')[0], // Today's date
        'publishAnonymously': _publishAnonymously,
        'customerName': _publishAnonymously ? 'Anonymous Customer' : (widget.user.displayName ?? 'Customer'),
        'hasPhotos': _selectedImages.isNotEmpty,
        'photoCount': _selectedImages.length,
        'photoUrls': photoUrls,
        'serviceAddress': widget.task.address, // Save task address for distance calculation
      };

      print('📝 Submitting review data: $reviewData');

      // Add review to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reviews')
          .add(reviewData);
          
      print('✅ Review submitted successfully with ID: ${docRef.id}');

      // Update provider stats (optional - could be done via Cloud Function)
      if (widget.task.assignedProviderId != null) {
        await _updateProviderStats();
      }

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Review submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back to tasks screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (error) {
      print('❌ Error submitting review: $error');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error submitting review: ${error.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  int _calculateOverallRating() {
    int rating = 3; // Base rating
    
    if (_serviceExpectationsMet == true) rating += 1;
    if (_serviceExpectationsMet == false) rating -= 1;
    
    if (_wouldRecommend == true) rating += 1;
    if (_wouldRecommend == false) rating -= 1;
    
    return rating.clamp(1, 5);
  }

  Future<void> _updateProviderStats() async {
    if (widget.task.assignedProviderId == null) return;
    
    try {
      final providerRef = FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.task.assignedProviderId!);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final providerDoc = await transaction.get(providerRef);
        
        if (providerDoc.exists) {
          final data = providerDoc.data()!;
          final currentJobs = data['total_jobs_completed'] ?? 0;
          final currentThumbsUp = data['thumbs_up_count'] ?? 0;
          
          int newThumbsUp = currentThumbsUp;
          if (_serviceExpectationsMet == true && _wouldRecommend == true) {
            newThumbsUp += 1;
          }
          
          transaction.update(providerRef, {
            'total_jobs_completed': currentJobs + 1,
            'thumbs_up_count': newThumbsUp,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (error) {
      print('❌ Error updating provider stats: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'New Review',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFBB04C)),
          onPressed: _currentPage > 0 ? _previousPage : () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          _buildRatingQuestionsPage(),
          _buildReviewTextPage(),
          _buildFinalSubmissionPage(),
        ],
      ),
    );
  }

  Widget _buildReviewTextPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            "You're reviewing:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Service info card
          _buildServiceInfoCard(),
          
          const SizedBox(height: 32),
          
          // Review text input
          Container(
            height: 200, // Fixed height instead of Expanded
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _reviewController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Share your experience...',
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Upload pictures section
          const TranslatableText(
            'Upload pictures',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Image upload area
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _selectedImages.isEmpty
                ? GestureDetector(
                    onTap: _pickImages,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Color(0xFFFBB04C),
                        ),
                        SizedBox(height: 8),
                        TranslatableText(
                          'Add photos',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TranslatableText(
                          'Camera or Gallery',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _selectedImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _selectedImages.length) {
                        // Add more photos button
                        return GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Color(0xFFFBB04C),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFFBB04C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Photo with remove button
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 32),
          
          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBB04C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            "You're reviewing:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Service info card
          _buildServiceInfoCard(),
          
          const SizedBox(height: 48),
          
          // First question
          const TranslatableText(
            'Did the service fulfill your expectations?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _serviceExpectationsMet = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _serviceExpectationsMet == true 
                          ? const Color(0xFFFBB04C).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _serviceExpectationsMet == true 
                            ? const Color(0xFFFBB04C)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.thumb_up,
                      size: 48,
                      color: _serviceExpectationsMet == true 
                          ? const Color(0xFFFBB04C)
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _serviceExpectationsMet = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _serviceExpectationsMet == false 
                          ? const Color(0xFFFBB04C).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _serviceExpectationsMet == false 
                            ? const Color(0xFFFBB04C)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.thumb_down,
                      size: 48,
                      color: _serviceExpectationsMet == false 
                          ? const Color(0xFFFBB04C)
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // Second question
          const TranslatableText(
            'Would you recommend this service to your friends?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _wouldRecommend = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _wouldRecommend == true 
                          ? const Color(0xFFFBB04C).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _wouldRecommend == true 
                            ? const Color(0xFFFBB04C)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.thumb_up,
                      size: 48,
                      color: _wouldRecommend == true 
                          ? const Color(0xFFFBB04C)
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _wouldRecommend = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _wouldRecommend == false 
                          ? const Color(0xFFFBB04C).withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _wouldRecommend == false 
                            ? const Color(0xFFFBB04C)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.thumb_down,
                      size: 48,
                      color: _wouldRecommend == false 
                          ? const Color(0xFFFBB04C)
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_serviceExpectationsMet != null && _wouldRecommend != null) 
                  ? _nextPage 
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBB04C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSubmissionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.check_circle,
              size: 50,
              color: Colors.green[700],
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Thank you for your review!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Your feedback helps us improve our services and helps other customers make informed decisions.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Privacy options card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: 20,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Publication Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Would you like to publish this review to help other customers?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Anonymous option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _publishAnonymously = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _publishAnonymously ? const Color(0xFFFBB04C).withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _publishAnonymously ? const Color(0xFFFBB04C) : Colors.grey[300]!,
                        width: _publishAnonymously ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _publishAnonymously ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _publishAnonymously ? const Color(0xFFFBB04C) : Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Publish anonymously',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your review will be shown as "Anonymous Customer"',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Named option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _publishAnonymously = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !_publishAnonymously ? const Color(0xFFFBB04C).withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_publishAnonymously ? const Color(0xFFFBB04C) : Colors.grey[300]!,
                        width: !_publishAnonymously ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_publishAnonymously ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: !_publishAnonymously ? const Color(0xFFFBB04C) : Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Publish with my name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your review will show your name and help build trust',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBB04C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Publishing Review...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Publish Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.serviceCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateTime.now().toString().split(' ')[0], // Today's date
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Provider info
          if (_isLoadingProvider)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFBB04C)),
              ),
            )
          else ...[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFBB04C),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.home_repair_service,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _providerData?['company'] ?? _providerData?['name'] ?? 'Unknown Provider',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
