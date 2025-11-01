import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/email_service.dart';
import '../../services/admin_notification_service.dart';
import '../../widgets/translatable_text.dart';
import '../home/hsp_home_screen.dart';
import 'hsp_storefront_setup_screen.dart';

class HspVerificationScreen extends StatefulWidget {
  final firebase_auth.User user;
  final String? email;
  final String? phoneNumber;

  const HspVerificationScreen({
    super.key,
    required this.user,
    this.email,
    this.phoneNumber,
  });

  @override
  State<HspVerificationScreen> createState() => _HspVerificationScreenState();
}

class _HspVerificationScreenState extends State<HspVerificationScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _legalRepNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  bool _backgroundCheckConsent = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  File? _governmentIdFile;
  File? _businessLicenseFile;
  File? _insuranceFile;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number if provided from phone authentication
    if (widget.phoneNumber != null) {
      _phoneController.text = widget.phoneNumber!;
    }
    
    // Debug authentication state
    _checkAuthState();
    
    // Load existing provider data for editing
    _loadExistingProviderData();
  }
  
  Future<void> _loadExistingProviderData() async {
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .get();
      
      if (providerDoc.exists) {
        final data = providerDoc.data() as Map<String, dynamic>;
        
        setState(() {
          // Pre-fill form fields with existing data
          _companyNameController.text = data['companyName'] ?? '';
          _legalRepNameController.text = data['legalRepresentativeName'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? widget.phoneNumber ?? '';
          _addressController.text = data['address'] ?? '';
          _backgroundCheckConsent = data['backgroundCheckConsent'] ?? false;
        });
        
        print('✅ Loaded existing provider data for editing');
      }
    } catch (e) {
      print('❌ Error loading existing provider data: $e');
    }
  }
  
  void _checkAuthState() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    print('🔍 Authentication State Check:');
    print('   User: ${user?.uid ?? "NOT AUTHENTICATED"}');
    print('   Email: ${user?.email ?? "N/A"}');
    print('   Phone: ${user?.phoneNumber ?? "N/A"}');
    print('   Provider ID: ${widget.user.uid}');
    print('   Auth method: ${user?.providerData.map((p) => p.providerId).toList() ?? "None"}');
    
    if (user == null) {
      print('🚨 USER NOT AUTHENTICATED - This will cause upload failures!');
    } else {
      print('✅ User is authenticated');
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _legalRepNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<String> _uploadDocumentWithRetry(File file, String documentType) async {
    const maxRetries = 3;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📤 Uploading $documentType (attempt $attempt/$maxRetries)');
        print('📁 File path: ${file.path}');
        print('📏 File size: ${await file.length()} bytes');
        print('👤 User ID: ${widget.user.uid}');
        
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('providers')
            .child(widget.user.uid)
            .child('verification_documents')
            .child('${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        print('🗂️ Storage path: ${storageRef.fullPath}');
        
        // Add timeout and better error handling
        final uploadTask = storageRef.putFile(file);
        
        // Set a reasonable timeout
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Upload timeout - please check your internet connection and try again');
          },
        );
        
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        print('✅ $documentType uploaded successfully to: $downloadUrl');
        return downloadUrl;
        
      } catch (e) {
        print('❌ Upload attempt $attempt failed: $e');
        print('🔍 Error type: ${e.runtimeType}');
        if (e.toString().contains('permission')) {
          print('🚨 Permission denied - check Firebase Storage rules');
        }
        if (e.toString().contains('network')) {
          print('🌐 Network error - check internet connection');
        }
        
        if (attempt == maxRetries) {
          throw Exception('Failed to upload $documentType after $maxRetries attempts: $e');
        }
        
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    
    throw Exception('Upload failed after all retries');
  }

  Future<void> _pickFile(String documentType) async {
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const TranslatableText('Select Image Source'),
            content: const TranslatableText('Choose how you want to add your document:'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const TranslatableText('Take Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const TranslatableText('Choose from Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const TranslatableText('Cancel'),
              ),
            ],
          );
        },
      );

      if (source == null) return; // User cancelled

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (pickedFile != null) {
        setState(() {
          switch (documentType) {
            case 'government_id':
              _governmentIdFile = File(pickedFile.path);
              break;
            case 'business_license':
              _businessLicenseFile = File(pickedFile.path);
              break;
            case 'insurance':
              _insuranceFile = File(pickedFile.path);
              break;
          }
        });
      }
    } catch (e) {
      // Handle specific camera permission errors
      String errorMessage = 'Failed to pick file: $e';
      
      if (e.toString().contains('camera_access_denied') || 
          e.toString().contains('Permission denied')) {
        errorMessage = 'Camera permission is required to take photos. Please enable camera access in Settings > Privacy & Security > Camera > Magic Home.';
      } else if (e.toString().contains('photo_access_denied')) {
        errorMessage = 'Photo library permission is required. Please enable photo access in Settings > Privacy & Security > Photos > Magic Home.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
      
      // Show user-friendly error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const TranslatableText('Permission Required'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatableText('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _skipVerificationForTesting() async {
    // Temporary function to skip document upload for testing
    setState(() {
      _isLoading = true;
      _errorMessage = 'Skipping document upload for testing...';
    });

    try {
      // Create provider profile without documents
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .update({
        'companyName': _companyNameController.text.trim(),
        'legalRepresentativeName': _legalRepNameController.text.trim(),
        'phoneNumber': widget.phoneNumber ?? _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'backgroundCheckConsent': _backgroundCheckConsent,
        'verificationStep': 'skipped_for_testing',
        'status': 'testing_mode',
        'verificationDocuments': {
          'governmentId': 'skipped_for_testing',
          'businessLicense': 'skipped_for_testing', 
          'insurance': 'skipped_for_testing',
        },
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Navigate to storefront setup
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HspStorefrontSetupScreen(
            user: widget.user,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
          ),
        ),
        (route) => false,
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Skip failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitVerification() async {
    // Validation
    if (_companyNameController.text.trim().isEmpty ||
        _legalRepNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    if (_governmentIdFile == null || _businessLicenseFile == null || _insuranceFile == null) {
      setState(() {
        _errorMessage = 'Please upload all required documents';
      });
      return;
    }

    if (!_backgroundCheckConsent) {
      setState(() {
        _errorMessage = 'Please consent to the background check';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      setState(() {
        _errorMessage = 'Validating files...';
      });

      // Check if files exist and are accessible
      for (final entry in {
        'Government ID': _governmentIdFile!,
        'Business License': _businessLicenseFile!,
        'Insurance': _insuranceFile!,
      }.entries) {
        if (!await entry.value.exists()) {
          throw Exception('${entry.key} file no longer exists. Please select again.');
        }
        final size = await entry.value.length();
        if (size == 0) {
          throw Exception('${entry.key} file is empty. Please select a valid file.');
        }
        print('${entry.key}: ${size} bytes');
      }

      setState(() {
        _errorMessage = 'Uploading documents to server...';
      });

      // Upload documents to Firebase Storage and notify admins
      Map<String, String> documentUrls = {};
      try {
        // Upload each document with retry logic
        setState(() {
          _errorMessage = 'Uploading government ID...';
        });
        documentUrls['governmentId'] = await _uploadDocumentWithRetry(_governmentIdFile!, 'governmentId');
        
        setState(() {
          _errorMessage = 'Uploading business license...';
        });
        documentUrls['businessLicense'] = await _uploadDocumentWithRetry(_businessLicenseFile!, 'businessLicense');
        
        setState(() {
          _errorMessage = 'Uploading insurance certificate...';
        });
        documentUrls['insurance'] = await _uploadDocumentWithRetry(_insuranceFile!, 'insurance');
        
        print('✅ All documents uploaded successfully');
        
        // Notify admins via push notification and Firestore
        await AdminNotificationService.notifyProviderVerificationSubmitted(
          providerId: widget.user.uid,
          providerName: _legalRepNameController.text.trim(),
          phoneNumber: widget.phoneNumber ?? _phoneController.text.trim(),
          email: widget.email,
          documentUrls: documentUrls,
        );
        
        print('✅ Admin notifications sent');
        
      } catch (uploadError) {
        print('❌ Document upload failed: $uploadError');
        setState(() {
          _errorMessage = 'Document upload failed: ${uploadError.toString()}\n\nTap "Skip Upload for Testing" to continue without documents.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = 'Updating your application status...';
      });

      // Only update status AFTER successful file upload and email sending
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .update({
        'companyName': _companyNameController.text.trim(),
        'legalRepresentativeName': _legalRepNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'backgroundCheckConsent': _backgroundCheckConsent,
        'verificationStep': 'documents_submitted',
        'status': 'under_review', // Set status for admin review
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Documents submitted successfully!';
      });

      // Small delay to show success message
      await Future.delayed(const Duration(seconds: 1));

      // Navigate to storefront setup screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HspStorefrontSetupScreen(
            user: widget.user,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Submission failed: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildFileUploadSection(String title, File? file, String documentType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFile(documentType),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: file != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        size: 40,
                        color: Color(0xFFFBB04C),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload Document',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const TranslatableText('Verification'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button too
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Company Name
            const Text(
              'Company Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter company name',
              ),
            ),
            const SizedBox(height: 20),

            // Legal Representative Name
            const Text(
              'Legal Representative Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _legalRepNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter legal representative name',
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter phone number',
              ),
            ),
            const SizedBox(height: 20),

            // Address
            const Text(
              'Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter business address',
              ),
            ),
            const SizedBox(height: 20),

            // Document Upload Sections
            _buildFileUploadSection(
              'Government ID (Legal Representative)',
              _governmentIdFile,
              'government_id',
            ),

            _buildFileUploadSection(
              'Business License',
              _businessLicenseFile,
              'business_license',
            ),

            _buildFileUploadSection(
              'Proof of Liability Insurance',
              _insuranceFile,
              'insurance',
            ),

            // Background check consent
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _backgroundCheckConsent,
                  onChanged: (value) {
                    setState(() {
                      _backgroundCheckConsent = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFFFBB04C),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _backgroundCheckConsent = !_backgroundCheckConsent;
                      });
                    },
                    child: const Text(
                      'By checking this box, you are authorizing us to initiate a background check. Please refer to our terms and conditions.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBB04C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Temporary skip button for testing
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _skipVerificationForTesting,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Skip Upload for Testing',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 